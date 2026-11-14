#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Une seule instance : relancer l'application (raccourci, démarrage de la
  // session) remontre celle qui tourne, cachée près de l'horloge ou non. Deux
  // instances feraient deux sauvegardes du PC en même temps.
  ::CreateMutexW(nullptr, TRUE, L"AlanyaCoffreFort.Instance");
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND existante = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"Alanya Coffre-fort");
    if (existante != nullptr) {
      ::ShowWindow(existante, SW_SHOW);
      if (::IsIconic(existante)) ::ShowWindow(existante, SW_RESTORE);
      ::SetForegroundWindow(existante);
    }
    return EXIT_SUCCESS;
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 800);
  if (!window.Create(L"Alanya Coffre-fort", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
