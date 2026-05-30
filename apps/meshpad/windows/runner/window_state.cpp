#include "window_state.h"

#include <flutter_windows.h>

#include <cmath>
#include <fstream>
#include <string>

#include <shlobj.h>

namespace meshpad {
namespace {

constexpr int kFileVersion = 3;
constexpr int kMinLogicalWidth = 400;
constexpr int kMinLogicalHeight = 300;

std::wstring GetStateFilePath() {
  wchar_t* path = nullptr;
  if (FAILED(SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, &path))) {
    return L"";
  }
  std::wstring file = std::wstring(path) + L"\\MeshPad\\window_state.ini";
  CoTaskMemFree(path);
  return file;
}

void EnsureParentDir(const std::wstring& file_path) {
  const auto pos = file_path.find_last_of(L"\\/");
  if (pos == std::wstring::npos) {
    return;
  }
  CreateDirectoryW(file_path.substr(0, pos).c_str(), nullptr);
}

double ScaleFactorForPoint(POINT point) {
  HMONITOR monitor =
      MonitorFromPoint(point, MONITOR_DEFAULTTONEAREST);
  if (!monitor) {
    monitor = MonitorFromPoint({0, 0}, MONITOR_DEFAULTTONEAREST);
  }
  const UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  return dpi / 96.0;
}

double ScaleFactorForPhysicalRect(const RECT& rect) {
  const POINT center = {(rect.left + rect.right) / 2,
                        (rect.top + rect.bottom) / 2};
  return ScaleFactorForPoint(center);
}

int PhysicalToLogical(int physical, double scale_factor) {
  return static_cast<int>(std::lround(physical / scale_factor));
}

int LogicalToPhysical(int logical, double scale_factor) {
  return static_cast<int>(std::lround(logical * scale_factor));
}

bool RectVisibleOnAnyMonitor(const RECT& physical_rect) {
  const int width = physical_rect.right - physical_rect.left;
  const int height = physical_rect.bottom - physical_rect.top;
  const double scale = ScaleFactorForPhysicalRect(physical_rect);
  if (width < LogicalToPhysical(kMinLogicalWidth, scale) ||
      height < LogicalToPhysical(kMinLogicalHeight, scale)) {
    return false;
  }

  const POINT probe = {(physical_rect.left + physical_rect.right) / 2,
                       (physical_rect.top + physical_rect.bottom) / 2};
  return MonitorFromPoint(probe, MONITOR_DEFAULTTONULL) != nullptr;
}

WindowState PhysicalStateFromRect(const RECT& rect, UINT show_cmd) {
  WindowState state;
  state.x = rect.left;
  state.y = rect.top;
  state.width = rect.right - rect.left;
  state.height = rect.bottom - rect.top;
  state.show_cmd = show_cmd;
  return state;
}

WindowState CenteredDefault(int default_width, int default_height) {
  RECT work_area = {};
  SystemParametersInfoW(SPI_GETWORKAREA, 0, &work_area, 0);

  const POINT work_center = {
      work_area.left + (work_area.right - work_area.left) / 2,
      work_area.top + (work_area.bottom - work_area.top) / 2,
  };
  const double scale = ScaleFactorForPoint(work_center);

  const int physical_width =
      LogicalToPhysical(default_width, scale);
  const int physical_height =
      LogicalToPhysical(default_height, scale);
  const int area_width = work_area.right - work_area.left;
  const int area_height = work_area.bottom - work_area.top;

  const int physical_x = work_area.left + (area_width - physical_width) / 2;
  const int physical_y = work_area.top + (area_height - physical_height) / 2;

  RECT rect = {physical_x, physical_y, physical_x + physical_width,
               physical_y + physical_height};
  return PhysicalStateFromRect(rect, SW_SHOWNORMAL);
}

bool IsValidPhysicalState(const WindowState& state) {
  if (state.width <= 0 || state.height <= 0) {
    return false;
  }

  const RECT physical = {state.x, state.y, state.x + state.width,
                         state.y + state.height};
  return RectVisibleOnAnyMonitor(physical);
}

}  // namespace

Win32Window::Point DefaultCenteredOrigin(const Win32Window::Size& size) {
  const WindowState state =
      CenteredDefault(static_cast<int>(size.width), static_cast<int>(size.height));
  const double scale =
      ScaleFactorForPhysicalRect({state.x, state.y, state.x + state.width,
                                  state.y + state.height});
  return Win32Window::Point(PhysicalToLogical(state.x, scale),
                            PhysicalToLogical(state.y, scale));
}

Win32Window::Size LogicalCreateSize(const WindowState& state) {
  const RECT physical = {state.x, state.y, state.x + state.width,
                         state.y + state.height};
  const double scale = ScaleFactorForPhysicalRect(physical);
  return Win32Window::Size(
      static_cast<unsigned int>(PhysicalToLogical(state.width, scale)),
      static_cast<unsigned int>(PhysicalToLogical(state.height, scale)));
}

WindowState LoadWindowState(int default_width, int default_height) {
  const std::wstring path = GetStateFilePath();
  if (path.empty()) {
    return CenteredDefault(default_width, default_height);
  }

  std::ifstream in(path);
  if (!in) {
    return CenteredDefault(default_width, default_height);
  }

  WindowState state;
  int file_version = 1;
  int dpi_at_save = 96;

  std::string line;
  while (std::getline(in, line)) {
    const auto eq = line.find('=');
    if (eq == std::string::npos) {
      continue;
    }
    const std::string key = line.substr(0, eq);
    const int value = std::stoi(line.substr(eq + 1));
    if (key == "version") {
      file_version = value;
    } else if (key == "dpi") {
      dpi_at_save = value;
    } else if (key == "x") {
      state.x = value;
    } else if (key == "y") {
      state.y = value;
    } else if (key == "width") {
      state.width = value;
    } else if (key == "height") {
      state.height = value;
    } else if (key == "show_cmd") {
      state.show_cmd = static_cast<UINT>(value);
    }
  }

  if (file_version == 2) {
    // v2 stored logical 96-DPI units — convert once to physical for v3.
    const double legacy_scale =
        dpi_at_save > 0 ? dpi_at_save / 96.0
                        : ScaleFactorForPoint({state.x, state.y});
    state.x = LogicalToPhysical(state.x, legacy_scale);
    state.y = LogicalToPhysical(state.y, legacy_scale);
    state.width = LogicalToPhysical(state.width, legacy_scale);
    state.height = LogicalToPhysical(state.height, legacy_scale);
  }

  if (!IsValidPhysicalState(state)) {
    return CenteredDefault(default_width, default_height);
  }

  return state;
}

void ApplyWindowState(HWND hwnd, const WindowState& state) {
  if (!hwnd) {
    return;
  }

  WINDOWPLACEMENT placement = {};
  placement.length = sizeof(WINDOWPLACEMENT);
  placement.flags =
      state.show_cmd == SW_SHOWMAXIMIZED ? WPF_RESTORETOMAXIMIZED : 0;
  placement.showCmd =
      state.show_cmd == SW_SHOWMAXIMIZED ? SW_SHOWMAXIMIZED : SW_SHOWNORMAL;
  placement.ptMinPosition = {0, 0};
  placement.ptMaxPosition = {0, 0};
  placement.rcNormalPosition = {state.x, state.y, state.x + state.width,
                                state.y + state.height};

  SetWindowPlacement(hwnd, &placement);
}

void SaveWindowState(HWND hwnd) {
  if (!hwnd) {
    return;
  }

  WINDOWPLACEMENT placement = {};
  placement.length = sizeof(WINDOWPLACEMENT);
  if (!GetWindowPlacement(hwnd, &placement)) {
    return;
  }

  const RECT& normal = placement.rcNormalPosition;
  const int width = normal.right - normal.left;
  const int height = normal.bottom - normal.top;
  if (width <= 0 || height <= 0) {
    return;
  }

  const WindowState state = PhysicalStateFromRect(normal, placement.showCmd);
  if (!IsValidPhysicalState(state)) {
    return;
  }

  const double scale = ScaleFactorForPhysicalRect(normal);
  const int dpi = static_cast<int>(std::lround(scale * 96.0));

  const std::wstring path = GetStateFilePath();
  if (path.empty()) {
    return;
  }

  EnsureParentDir(path);

  std::ofstream out(path, std::ios::trunc);
  if (!out) {
    return;
  }

  // Store physical placement pixels as-is to avoid round-trip drift on restart.
  out << "version=" << kFileVersion << '\n';
  out << "dpi=" << dpi << '\n';
  out << "x=" << normal.left << '\n';
  out << "y=" << normal.top << '\n';
  out << "width=" << width << '\n';
  out << "height=" << height << '\n';
  out << "show_cmd=" << placement.showCmd << '\n';
}

}  // namespace meshpad
