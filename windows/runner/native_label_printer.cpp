#include "native_label_printer.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <cstdint>
#include <memory>
#include <string>
#include <vector>

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

const EncodableValue* Find(const EncodableMap& map, const char* key) {
  const auto it = map.find(EncodableValue(key));
  return it == map.end() ? nullptr : &it->second;
}

std::wstring Utf16FromUtf8(const std::string& value) {
  if (value.empty()) return {};
  const int size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                       value.data(),
                                       static_cast<int>(value.size()), nullptr,
                                       0);
  if (size <= 0) return {};
  std::wstring result(size, L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                      static_cast<int>(value.size()), result.data(), size);
  return result;
}

bool PrintRgbaPages(const std::wstring& printer_name,
                    const std::wstring& job_name,
                    const EncodableList& pages, std::string* error) {
  HANDLE printer = nullptr;
  if (!OpenPrinter(const_cast<wchar_t*>(printer_name.c_str()), &printer,
                   nullptr)) {
    *error = "Windows could not open the selected printer";
    return false;
  }

  // Start with the driver's complete DEVMODE, including Godex's private
  // media/gap configuration, and override only the physical label geometry.
  // The installed driver currently advertises a generic 101.6x101.6-mm USER
  // stock, which either enlarges and crops the bitmap or drops a smaller DIB.
  const LONG devmode_size = DocumentProperties(
      nullptr, printer, const_cast<wchar_t*>(printer_name.c_str()), nullptr,
      nullptr, 0);
  if (devmode_size <= 0) {
    ClosePrinter(printer);
    *error = "Windows could not read the printer settings";
    return false;
  }
  std::vector<uint8_t> devmode_storage(devmode_size);
  auto* devmode = reinterpret_cast<DEVMODE*>(devmode_storage.data());
  if (DocumentProperties(nullptr, printer,
                         const_cast<wchar_t*>(printer_name.c_str()), devmode,
                         nullptr, DM_OUT_BUFFER) != IDOK) {
    ClosePrinter(printer);
    *error = "Windows could not load the printer settings";
    return false;
  }
  devmode->dmFields |=
      DM_ORIENTATION | DM_PAPERSIZE | DM_PAPERWIDTH | DM_PAPERLENGTH;
  devmode->dmOrientation = DMORIENT_PORTRAIT;
  devmode->dmPaperSize = 0;
  // DEVMODE dimensions are tenths of a millimetre. The roll is 58 mm across
  // the print head and advances 40 mm per label; keeping this in the driver's
  // unrotated orientation makes the finished artwork horizontal.
  devmode->dmPaperWidth = 580;
  devmode->dmPaperLength = 400;

  HDC dc = CreateDC(L"WINSPOOL", printer_name.c_str(), nullptr, devmode);
  ClosePrinter(printer);
  if (dc == nullptr) {
    *error = "Windows could not create the 58x40-mm printer page";
    return false;
  }

  DOCINFO doc_info{};
  doc_info.cbSize = sizeof(doc_info);
  doc_info.lpszDocName = job_name.c_str();
  if (StartDoc(dc, &doc_info) <= 0) {
    *error = "Windows could not start the print job";
    DeleteDC(dc);
    return false;
  }

  const int offset_x = GetDeviceCaps(dc, PHYSICALOFFSETX);
  const int offset_y = GetDeviceCaps(dc, PHYSICALOFFSETY);
  bool ok = true;

  for (const auto& page_value : pages) {
    const auto* page = std::get_if<EncodableMap>(&page_value);
    if (page == nullptr) {
      ok = false;
      break;
    }
    const auto* width_value = Find(*page, "width");
    const auto* height_value = Find(*page, "height");
    const auto* pixels_value = Find(*page, "pixels");
    if (width_value == nullptr || height_value == nullptr ||
        pixels_value == nullptr) {
      ok = false;
      break;
    }
    const auto* width = std::get_if<int32_t>(width_value);
    const auto* height = std::get_if<int32_t>(height_value);
    const auto* rgba = std::get_if<std::vector<uint8_t>>(pixels_value);
    if (width == nullptr || height == nullptr || rgba == nullptr ||
        *width <= 0 || *height <= 0 ||
        rgba->size() != static_cast<size_t>(*width) * *height * 4) {
      ok = false;
      break;
    }

    // PDFium's raster contains anti-aliased gray edge pixels. A monochrome
    // thermal driver dithers those pixels, making QR edges and small artwork
    // look fuzzy. Convert once to pure black/white at the printer's native
    // resolution and use a padded 24-bit DIB, which the Godex driver handles
    // without alpha blending or color dithering.
    const size_t dib_stride =
        (static_cast<size_t>(*width) * 3 + 3) & ~static_cast<size_t>(3);
    std::vector<uint8_t> bgr(dib_stride * *height, 0xff);
    for (int y = 0; y < *height; y++) {
      for (int x = 0; x < *width; x++) {
        const size_t source =
            (static_cast<size_t>(y) * *width + x) * 4;
        const int luminance = ((*rgba)[source] * 299 +
                               (*rgba)[source + 1] * 587 +
                               (*rgba)[source + 2] * 114) /
                              1000;
        const uint8_t value = luminance < 176 ? 0x00 : 0xff;
        const size_t target = static_cast<size_t>(y) * dib_stride + x * 3;
        bgr[target] = value;
        bgr[target + 1] = value;
        bgr[target + 2] = value;
      }
    }

    BITMAPINFO bitmap_info{};
    bitmap_info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bitmap_info.bmiHeader.biWidth = *width;
    bitmap_info.bmiHeader.biHeight = -*height;  // top-down DIB
    bitmap_info.bmiHeader.biPlanes = 1;
    bitmap_info.bmiHeader.biBitCount = 24;
    bitmap_info.bmiHeader.biCompression = BI_RGB;

    if (StartPage(dc) <= 0) {
      ok = false;
      break;
    }
    SetStretchBltMode(dc, COLORONCOLOR);
    const int page_width = GetDeviceCaps(dc, PHYSICALWIDTH);
    const int page_height = GetDeviceCaps(dc, PHYSICALHEIGHT);
    if (page_width <= 0 || page_height <= 0) {
      ok = false;
      break;
    }
    // The HDC is explicitly 58x40 mm now, so this is a full-page operation
    // (the form thermal drivers reliably accept) without the old 4x4 scaling.
    const int rendered = StretchDIBits(
        dc, -offset_x, -offset_y, page_width, page_height, 0, 0, *width,
        *height, bgr.data(), &bitmap_info, DIB_RGB_COLORS, SRCCOPY);
    if (rendered == GDI_ERROR || EndPage(dc) <= 0) {
      ok = false;
      break;
    }
  }

  if (ok) {
    ok = EndDoc(dc) > 0;
  } else {
    AbortDoc(dc);
  }
  DeleteDC(dc);
  if (!ok) *error = "Windows failed while writing the label bitmap";
  return ok;
}

}  // namespace

void RegisterNativeLabelPrinter(flutter::FlutterEngine* engine) {
  auto channel = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      engine->messenger(), "cashier/native_label_printer",
      &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler(
      [](const auto& call, auto result) {
        if (call.method_name() != "printRgbaPages") {
          result->NotImplemented();
          return;
        }
        const auto* args = std::get_if<EncodableMap>(call.arguments());
        if (args == nullptr) {
          result->Error("bad-arguments", "Expected a map of print arguments");
          return;
        }
        const auto* printer_value = Find(*args, "printerName");
        const auto* job_value = Find(*args, "jobName");
        const auto* pages_value = Find(*args, "pages");
        const auto* printer = printer_value == nullptr
                                  ? nullptr
                                  : std::get_if<std::string>(printer_value);
        const auto* job = job_value == nullptr
                              ? nullptr
                              : std::get_if<std::string>(job_value);
        const auto* pages = pages_value == nullptr
                                ? nullptr
                                : std::get_if<EncodableList>(pages_value);
        if (printer == nullptr || job == nullptr || pages == nullptr ||
            pages->empty()) {
          result->Error("bad-arguments", "Printer, job, or pages are missing");
          return;
        }
        std::string error;
        const bool ok = PrintRgbaPages(Utf16FromUtf8(*printer),
                                       Utf16FromUtf8(*job), *pages, &error);
        if (!ok) {
          result->Error("print-failed", error);
          return;
        }
        result->Success(EncodableValue(true));
      });
}
