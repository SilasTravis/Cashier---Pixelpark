#include <flutter/dart_project.h>
#include <flutter/flutter_engine.h>
#include <printing/printing_plugin.h>
#include <windows.h>

#include <chrono>
#include <thread>

#include "flutter_window.h"
#include "native_label_printer.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  // A driver can hang inside EnumPrinters or StartDoc. Keep those calls
  // outside the cashier window's message loop and never open a second till.
  if (command_line_arguments.size() == 1 &&
      command_line_arguments.front() == "--cashier-print-job") {
    // Also bound the worker if the parent exits while the driver is hung.
    std::thread([] {
      std::this_thread::sleep_for(std::chrono::seconds(25));
      ::TerminateProcess(::GetCurrentProcess(), EXIT_FAILURE);
    }).detach();
    flutter::FlutterEngine engine(project);
    if (!engine.Run("printJobMain")) return EXIT_FAILURE;
    PrintingPluginRegisterWithRegistrar(
        engine.GetRegistrarForPlugin("PrintingPlugin"));
    RegisterNativeLabelPrinter(&engine);
    ::MSG msg;
    while (::GetMessage(&msg, nullptr, 0, 0) > 0) {
      ::TranslateMessage(&msg);
      ::DispatchMessage(&msg);
    }
    return EXIT_FAILURE;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"cashier_app", origin, size)) {
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
