//! libp2p swarm: mDNS + JSON wire request-response (PLAN 8.1).
use std::{
    collections::{HashMap, HashSet},
    sync::{Arc, Mutex},
    time::Duration,
};

use futures::StreamExt;
use libp2p::{
    PeerId, Swarm, SwarmBuilder,
    identify,
    mdns,
    multiaddr::Protocol,
    request_response::{self, ProtocolSupport},
    swarm::SwarmEvent,
};
use tokio::sync::{broadcast, mpsc, oneshot};
use tracing::{info, warn};

use crate::events::SidecarEvent;
use crate::wire_attachment_store::WireAttachmentStore;
use crate::wire_batch;
use crate::wire_protocol::{WireRequest, WireResponse, WIRE_PROTOCOL};
use crate::wire_store::WireStore;

/// Result of libp2p batch sync (pull remote batch + push local batch).
pub struct SyncBatchStats {
    pub imported: u32,
    pub pushed: u32,
}

const AGENT_PREFIX: &str = "meshpad/";

pub struct P2pConfig {
    pub events: broadcast::Sender<SidecarEvent>,
    /// This sidecar's HTTP port (for `wire_base` hints to peers).
    pub http_listen_port: u16,
    /// Assumed LAN HTTP port on discovered peers (MeshPad app).
    pub default_lan_http_port: u16,
    pub default_tls_port: u16,
}

pub struct P2pController {
    cmd_tx: mpsc::Sender<P2pCommand>,
}

enum P2pCommand {
    Stop,
    PullFromMeshpadPeer {
        meshpad_peer_id: String,
        reply: oneshot::Sender<Result<u32, String>>,
    },
    PushToMeshpadPeer {
        meshpad_peer_id: String,
        reply: oneshot::Sender<Result<u32, String>>,
    },
    BatchSyncWithMeshpadPeer {
        meshpad_peer_id: String,
        reply: oneshot::Sender<Result<SyncBatchStats, String>>,
    },
}

#[derive(libp2p::swarm::NetworkBehaviour)]
struct MeshpadBehaviour {
    mdns: mdns::tokio::Behaviour,
    identify: identify::Behaviour,
    wire: request_response::json::Behaviour<WireRequest, WireResponse>,
}

#[derive(Clone, Copy)]
enum PullStep {
    AwaitingCatalog,
    AwaitingNotes,
}

struct PullCtx {
    peer: PeerId,
    reply: oneshot::Sender<Result<u32, String>>,
    step: PullStep,
}

struct PushCtx {
    peer: PeerId,
    reply: oneshot::Sender<Result<u32, String>>,
    remaining: Vec<serde_json::Value>,
    pushed: u32,
}

#[derive(Clone, Copy)]
enum BatchSyncStep {
    AwaitingRemoteBatch,
    AwaitingPushAck,
}

struct BatchSyncCtx {
    peer: PeerId,
    reply: oneshot::Sender<Result<SyncBatchStats, String>>,
    step: BatchSyncStep,
    imported: u32,
}

pub fn spawn(
    wire: Arc<Mutex<WireStore>>,
    attachments: Arc<Mutex<WireAttachmentStore>>,
    local_peer_id: String,
    display_name: String,
    config: P2pConfig,
) -> P2pController {
    let (cmd_tx, cmd_rx) = mpsc::channel(32);
    tokio::spawn(async move {
        if let Err(err) =
            run_swarm(wire, attachments, local_peer_id, display_name, config, cmd_rx).await
        {
            warn!("libp2p swarm exited: {err}");
        }
    });
    P2pController { cmd_tx }
}

impl P2pController {
    pub async fn stop(&self) {
        let _ = self.cmd_tx.send(P2pCommand::Stop).await;
    }

    pub async fn pull_from_meshpad_peer(&self, meshpad_peer_id: &str) -> Result<u32, String> {
        let (reply_tx, reply_rx) = oneshot::channel();
        self.cmd_tx
            .send(P2pCommand::PullFromMeshpadPeer {
                meshpad_peer_id: meshpad_peer_id.to_string(),
                reply: reply_tx,
            })
            .await
            .map_err(|e| e.to_string())?;
        reply_rx.await.map_err(|e| e.to_string())?
    }

    pub async fn push_to_meshpad_peer(&self, meshpad_peer_id: &str) -> Result<u32, String> {
        let (reply_tx, reply_rx) = oneshot::channel();
        self.cmd_tx
            .send(P2pCommand::PushToMeshpadPeer {
                meshpad_peer_id: meshpad_peer_id.to_string(),
                reply: reply_tx,
            })
            .await
            .map_err(|e| e.to_string())?;
        reply_rx.await.map_err(|e| e.to_string())?
    }

    pub async fn batch_sync_from_meshpad_peer(
        &self,
        meshpad_peer_id: &str,
    ) -> Result<SyncBatchStats, String> {
        let (reply_tx, reply_rx) = oneshot::channel();
        self.cmd_tx
            .send(P2pCommand::BatchSyncWithMeshpadPeer {
                meshpad_peer_id: meshpad_peer_id.to_string(),
                reply: reply_tx,
            })
            .await
            .map_err(|e| e.to_string())?;
        reply_rx.await.map_err(|e| e.to_string())?
    }
}

async fn run_swarm(
    wire: Arc<Mutex<WireStore>>,
    attachments: Arc<Mutex<WireAttachmentStore>>,
    local_peer_id: String,
    display_name: String,
    config: P2pConfig,
    mut cmd_rx: mpsc::Receiver<P2pCommand>,
) -> Result<(), String> {
    let local_key = libp2p::identity::Keypair::generate_ed25519();
    let agent_version = format!("{AGENT_PREFIX}{local_peer_id}/{display_name}");

    let mut swarm = SwarmBuilder::with_existing_identity(local_key)
        .with_tokio()
        .with_tcp(
            libp2p::tcp::Config::default(),
            libp2p::noise::Config::new,
            libp2p::yamux::Config::default,
        )
        .map_err(|e| e.to_string())?
        .with_behaviour(|key| {
            let wire_proto = [(
                libp2p::StreamProtocol::new(WIRE_PROTOCOL),
                ProtocolSupport::Full,
            )];
            let wire =
                request_response::json::Behaviour::<WireRequest, WireResponse>::new(
                    wire_proto,
                    request_response::Config::default(),
                );
            let mdns = mdns::tokio::Behaviour::new(
                mdns::Config::default(),
                key.public().to_peer_id(),
            )
            .map_err(|e| std::io::Error::other(e.to_string()))?;
            let identify = identify::Behaviour::new(identify::Config::new(
                agent_version,
                key.public(),
            ));
            Ok(MeshpadBehaviour {
                mdns,
                identify,
                wire,
            })
        })
        .map_err(|e| e.to_string())?
        .with_swarm_config(|cfg| {
            cfg.with_idle_connection_timeout(Duration::from_secs(90))
        })
        .build();

    swarm
        .listen_on("/ip4/0.0.0.0/tcp/0".parse().unwrap())
        .map_err(|e| e.to_string())?;

    let mut meshpad_peers: HashMap<String, PeerId> = HashMap::new();
    let mut announced: HashSet<String> = HashSet::new();
    let mut pulls: HashMap<request_response::OutboundRequestId, PullCtx> = HashMap::new();
    let mut pushes: HashMap<request_response::OutboundRequestId, PushCtx> = HashMap::new();
    let mut batch_syncs: HashMap<request_response::OutboundRequestId, BatchSyncCtx> =
        HashMap::new();

    loop {
        tokio::select! {
            cmd = cmd_rx.recv() => {
                match cmd {
                    Some(P2pCommand::Stop) | None => break,
                    Some(P2pCommand::PullFromMeshpadPeer { meshpad_peer_id, reply }) => {
                        let Some(peer) = meshpad_peers.get(&meshpad_peer_id).copied() else {
                            let _ = reply.send(Err(format!(
                                "libp2p peer {meshpad_peer_id} not connected (mdns/identify)"
                            )));
                            continue;
                        };
                        let req_id = swarm
                            .behaviour_mut()
                            .wire
                            .send_request(&peer, WireRequest::GetCatalog);
                        pulls.insert(
                            req_id,
                            PullCtx {
                                peer,
                                reply,
                                step: PullStep::AwaitingCatalog,
                            },
                        );
                    }
                    Some(P2pCommand::PushToMeshpadPeer { meshpad_peer_id, reply }) => {
                        let Some(peer) = meshpad_peers.get(&meshpad_peer_id).copied() else {
                            let _ = reply.send(Err(format!(
                                "libp2p peer {meshpad_peer_id} not connected"
                            )));
                            continue;
                        };
                        let snapshots = wire.lock().expect("wire lock").all_snapshots();
                        if snapshots.is_empty() {
                            let _ = reply.send(Ok(0));
                            continue;
                        }
                        let first = snapshots[0].clone();
                        let rest = snapshots.into_iter().skip(1).collect();
                        let req_id = swarm.behaviour_mut().wire.send_request(
                            &peer,
                            WireRequest::Push { snapshot: first },
                        );
                        pushes.insert(
                            req_id,
                            PushCtx {
                                peer,
                                reply,
                                remaining: rest,
                                pushed: 0,
                            },
                        );
                    }
                    Some(P2pCommand::BatchSyncWithMeshpadPeer { meshpad_peer_id, reply }) => {
                        let Some(peer) = meshpad_peers.get(&meshpad_peer_id).copied() else {
                            let _ = reply.send(Err(format!(
                                "libp2p peer {meshpad_peer_id} not connected"
                            )));
                            continue;
                        };
                        let req_id = swarm
                            .behaviour_mut()
                            .wire
                            .send_request(&peer, WireRequest::GetBatch);
                        batch_syncs.insert(
                            req_id,
                            BatchSyncCtx {
                                peer,
                                reply,
                                step: BatchSyncStep::AwaitingRemoteBatch,
                                imported: 0,
                            },
                        );
                    }
                }
            }
            event = swarm.select_next_some() => {
                handle_swarm_event(
                    &mut swarm,
                    &wire,
                    &attachments,
                    &config,
                    &mut meshpad_peers,
                    &mut announced,
                    &mut pulls,
                    &mut pushes,
                    &mut batch_syncs,
                    event,
                );
            }
        }
    }
    Ok(())
}

fn handle_swarm_event(
    swarm: &mut Swarm<MeshpadBehaviour>,
    wire: &Arc<Mutex<WireStore>>,
    attachments: &Arc<Mutex<WireAttachmentStore>>,
    config: &P2pConfig,
    meshpad_peers: &mut HashMap<String, PeerId>,
    announced: &mut HashSet<String>,
    pulls: &mut HashMap<request_response::OutboundRequestId, PullCtx>,
    pushes: &mut HashMap<request_response::OutboundRequestId, PushCtx>,
    batch_syncs: &mut HashMap<request_response::OutboundRequestId, BatchSyncCtx>,
    event: SwarmEvent<MeshpadBehaviourEvent>,
) {
    match event {
        SwarmEvent::Behaviour(MeshpadBehaviourEvent::Mdns(mdns::Event::Discovered(list))) => {
            for (peer, addr) in list {
                info!("mdns discovered {peer} at {addr}");
                swarm.dial(addr.with(Protocol::P2p(peer))).ok();
            }
        }
        SwarmEvent::Behaviour(MeshpadBehaviourEvent::Mdns(mdns::Event::Expired(list))) => {
            for (peer, _) in list {
                meshpad_peers.retain(|_, pid| *pid != peer);
                announced.retain(|id| meshpad_peers.contains_key(id));
            }
        }
        SwarmEvent::Behaviour(MeshpadBehaviourEvent::Identify(
            identify::Event::Received { peer_id, info, .. },
        )) => {
            if let Some((meshpad_id, peer_name)) = parse_meshpad_agent(&info.agent_version) {
                info!("identify {peer_id} meshpad_id={meshpad_id}");
                meshpad_peers.insert(meshpad_id.clone(), peer_id);
                if announced.insert(meshpad_id.clone()) {
                    let lan_host = remote_ip_for_peer(swarm, peer_id);
                    let wire_base = lan_host.as_ref().map(|host| {
                        format!(
                            "http://{host}:{}/",
                            config.default_lan_http_port
                        )
                    });
                    let _ = config.events.send(SidecarEvent::peer_discovered(
                        meshpad_id,
                        peer_name,
                        lan_host,
                        Some(config.default_lan_http_port),
                        Some(config.default_tls_port),
                        wire_base,
                    ));
                }
            }
        }
        SwarmEvent::Behaviour(MeshpadBehaviourEvent::Wire(
            request_response::Event::Message { peer, message },
        )) => match message {
            request_response::Message::Request { request, channel, .. } => {
                let response = match request {
                    WireRequest::Hello {
                        peer_id: meshpad_id,
                        display_name,
                    } => {
                        meshpad_peers.insert(meshpad_id.clone(), peer);
                        if announced.insert(meshpad_id.clone()) {
                            let lan_host = remote_ip_for_peer(swarm, peer);
                            let wire_base = lan_host.as_ref().map(|host| {
                                format!("http://{host}:{}/", config.default_lan_http_port)
                            });
                            let _ = config.events.send(SidecarEvent::peer_discovered(
                                meshpad_id,
                                display_name,
                                lan_host,
                                Some(config.default_lan_http_port),
                                Some(config.default_tls_port),
                                wire_base,
                            ));
                        }
                        WireResponse::HelloAck
                    }
                    WireRequest::GetCatalog => {
                        let heads = wire.lock().expect("wire lock").catalog_heads();
                        WireResponse::Catalog { heads }
                    }
                    WireRequest::Pull { note_ids } => {
                        let notes = wire.lock().expect("wire lock").pull(&note_ids);
                        WireResponse::Pull { notes }
                    }
                    WireRequest::Push { snapshot } => {
                        wire.lock().expect("wire lock").upsert(snapshot);
                        WireResponse::PushAck
                    }
                    WireRequest::GetBatch => {
                        let batch = {
                            let w = wire.lock().expect("wire lock");
                            let a = attachments.lock().expect("attachments lock");
                            wire_batch::export_batch(&w, &a)
                        };
                        WireResponse::Batch { batch }
                    }
                    WireRequest::PushBatch { batch } => {
                        let imported = {
                            let mut w = wire.lock().expect("wire lock");
                            let mut a = attachments.lock().expect("attachments lock");
                            wire_batch::import_batch(&batch, &mut w, &mut a)
                        };
                        WireResponse::BatchAck { imported }
                    }
                };
                swarm.behaviour_mut().wire.send_response(channel, response).ok();
            }
            request_response::Message::Response {
                request_id,
                response,
            } => {
                if pulls.contains_key(&request_id) {
                    handle_pull_response(swarm, wire, pulls, request_id, response);
                } else if pushes.contains_key(&request_id) {
                    handle_push_response(swarm, pushes, request_id, response);
                } else if batch_syncs.contains_key(&request_id) {
                    handle_batch_sync_response(
                        swarm,
                        wire,
                        attachments,
                        batch_syncs,
                        request_id,
                        response,
                    );
                }
            }
        },
        SwarmEvent::Behaviour(MeshpadBehaviourEvent::Wire(
            request_response::Event::OutboundFailure { request_id, error, .. },
        )) => {
            if let Some(ctx) = pulls.remove(&request_id) {
                let _ = ctx
                    .reply
                    .send(Err(format!("libp2p outbound failure: {error}")));
            } else if let Some(ctx) = pushes.remove(&request_id) {
                let _ = ctx
                    .reply
                    .send(Err(format!("libp2p push failure: {error}")));
            } else if let Some(ctx) = batch_syncs.remove(&request_id) {
                let _ = ctx
                    .reply
                    .send(Err(format!("libp2p batch sync failure: {error}")));
            }
        }
        SwarmEvent::NewListenAddr { address, .. } => {
            info!("libp2p listening on {address}");
        }
        _ => {}
    }
}

fn handle_pull_response(
    swarm: &mut Swarm<MeshpadBehaviour>,
    wire: &Arc<Mutex<WireStore>>,
    pulls: &mut HashMap<request_response::OutboundRequestId, PullCtx>,
    request_id: request_response::OutboundRequestId,
    response: WireResponse,
) {
    let Some(ctx) = pulls.get(&request_id) else {
        return;
    };
    let peer = ctx.peer;
    let step = ctx.step;

    match (step, response) {
        (PullStep::AwaitingCatalog, WireResponse::Catalog { heads }) => {
            let note_ids: Vec<String> = heads
                .iter()
                .filter_map(|h| h.get("id").and_then(|v| v.as_str()).map(str::to_string))
                .collect();
            if note_ids.is_empty() {
                if let Some(ctx) = pulls.remove(&request_id) {
                    let _ = ctx.reply.send(Ok(0));
                }
                return;
            }
            let pull_id = swarm.behaviour_mut().wire.send_request(
                &peer,
                WireRequest::Pull {
                    note_ids: note_ids.clone(),
                },
            );
            if let Some(mut ctx) = pulls.remove(&request_id) {
                ctx.step = PullStep::AwaitingNotes;
                pulls.insert(pull_id, ctx);
            }
        }
        (PullStep::AwaitingNotes, WireResponse::Pull { notes }) => {
            let imported = wire.lock().expect("wire lock").import_snapshots(notes);
            if let Some(ctx) = pulls.remove(&request_id) {
                let _ = ctx.reply.send(Ok(imported));
            }
        }
        (_, WireResponse::Error { message }) => {
            if let Some(ctx) = pulls.remove(&request_id) {
                let _ = ctx.reply.send(Err(message));
            }
        }
        _ => {}
    }
}

fn handle_batch_sync_response(
    swarm: &mut Swarm<MeshpadBehaviour>,
    wire: &Arc<Mutex<WireStore>>,
    attachments: &Arc<Mutex<WireAttachmentStore>>,
    batch_syncs: &mut HashMap<request_response::OutboundRequestId, BatchSyncCtx>,
    request_id: request_response::OutboundRequestId,
    response: WireResponse,
) {
    let Some(mut ctx) = batch_syncs.remove(&request_id) else {
        return;
    };

    match (ctx.step, response) {
        (BatchSyncStep::AwaitingRemoteBatch, WireResponse::Batch { batch }) => {
            ctx.imported = {
                let mut w = wire.lock().expect("wire lock");
                let mut a = attachments.lock().expect("attachments lock");
                wire_batch::import_batch(&batch, &mut w, &mut a)
            };
            let local_batch = {
                let w = wire.lock().expect("wire lock");
                let a = attachments.lock().expect("attachments lock");
                wire_batch::export_batch(&w, &a)
            };
            let peer = ctx.peer;
            let push_id = swarm.behaviour_mut().wire.send_request(
                &peer,
                WireRequest::PushBatch { batch: local_batch },
            );
            ctx.step = BatchSyncStep::AwaitingPushAck;
            batch_syncs.insert(push_id, ctx);
        }
        (BatchSyncStep::AwaitingPushAck, WireResponse::BatchAck { imported }) => {
            let _ = ctx.reply.send(Ok(SyncBatchStats {
                imported: ctx.imported,
                pushed: imported,
            }));
        }
        (_, WireResponse::Error { message }) => {
            let _ = ctx.reply.send(Err(message));
        }
        _ => {
            let _ = ctx.reply.send(Err(
                "unexpected wire response during batch sync".into(),
            ));
        }
    }
}

fn handle_push_response(
    swarm: &mut Swarm<MeshpadBehaviour>,
    pushes: &mut HashMap<request_response::OutboundRequestId, PushCtx>,
    request_id: request_response::OutboundRequestId,
    response: WireResponse,
) {
    let Some(mut ctx) = pushes.remove(&request_id) else {
        return;
    };

    match response {
        WireResponse::PushAck => {
            ctx.pushed += 1;
            if let Some(next) = ctx.remaining.first().cloned() {
                ctx.remaining.remove(0);
                let peer = ctx.peer;
                let new_id = swarm.behaviour_mut().wire.send_request(
                    &peer,
                    WireRequest::Push { snapshot: next },
                );
                pushes.insert(new_id, ctx);
            } else {
                let _ = ctx.reply.send(Ok(ctx.pushed));
            }
        }
        WireResponse::Error { message } => {
            let _ = ctx.reply.send(Err(message));
        }
        _ => {
            let _ = ctx
                .reply
                .send(Err("unexpected wire response during push".into()));
        }
    }
}

fn remote_ip_for_peer(swarm: &Swarm<MeshpadBehaviour>, peer: PeerId) -> Option<String> {
    swarm.connected_addresses(peer).find_map(|addr| {
        for protocol in addr.iter() {
            match protocol {
                Protocol::Ip4(ip) => return Some(ip.to_string()),
                Protocol::Ip6(ip) => return Some(ip.to_string()),
                _ => {}
            }
        }
        None
    })
}

fn parse_meshpad_agent(agent: &str) -> Option<(String, String)> {
    let rest = agent.strip_prefix(AGENT_PREFIX)?;
    let mut parts = rest.splitn(2, '/');
    let peer_id = parts.next()?.trim();
    if peer_id.is_empty() {
        return None;
    }
    let display_name = parts
        .next()
        .filter(|s| !s.is_empty())
        .unwrap_or("MeshPad")
        .to_string();
    Some((peer_id.to_string(), display_name))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_meshpad_agent_splits_id_and_name() {
        let parsed = parse_meshpad_agent("meshpad/peer-a/My Device").unwrap();
        assert_eq!(parsed.0, "peer-a");
        assert_eq!(parsed.1, "My Device");
    }
}
