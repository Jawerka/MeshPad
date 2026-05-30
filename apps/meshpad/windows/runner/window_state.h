#ifndef RUNNER_WINDOW_STATE_H_
#define RUNNER_WINDOW_STATE_H_

#include <windows.h>

#include <optional>

#include "win32_window.h"

namespace meshpad {

// Physical screen pixels from WINDOWPLACEMENT::rcNormalPosition.
struct WindowState {
  int x = 0;
  int y = 0;
  int width = 1280;
  int height = 720;
  UINT show_cmd = SW_SHOWNORMAL;
};

// Returns saved state, or centered default size if none / invalid.
WindowState LoadWindowState(int default_width, int default_height);

void SaveWindowState(HWND hwnd);

// Applies saved physical placement via SetWindowPlacement.
void ApplyWindowState(HWND hwnd, const WindowState& state);

// Logical size for Win32Window::Create (exact position comes from ApplyWindowState).
Win32Window::Size LogicalCreateSize(const WindowState& state);

Win32Window::Point DefaultCenteredOrigin(const Win32Window::Size& size);

}  // namespace meshpad

#endif  // RUNNER_WINDOW_STATE_H_
