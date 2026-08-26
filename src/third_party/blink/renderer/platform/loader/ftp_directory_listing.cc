// Copyright 2018 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "third_party/blink/renderer/platform/loader/ftp_directory_listing.h"

#include <optional>
#include <string>
#include <vector>

#include "base/byte_size.h"
#include "base/containers/span.h"
#include "base/i18n/encoding_detection.h"
#include "base/i18n/icu_string_conversions.h"
#include "base/numerics/safe_conversions.h"
#include "base/strings/escape.h"
#include "base/strings/string_util.h"
#include "base/strings/sys_string_conversions.h"
#include "base/strings/utf_string_conversions.h"
#include "base/time/time.h"
#include "net/base/module/directory_listing.h"
#include "net/base/net_errors.h"
#include "net/ftp/ftp_directory_listing_parser.h"
#include "net/net_buildflags.h"
#include "third_party/blink/renderer/platform/loader/fetch/resource_error.h"
#include "third_party/blink/renderer/platform/weborigin/kurl.h"
#include "third_party/blink/renderer/platform/wtf/shared_buffer.h"
#include "url/gurl.h"

namespace blink {

namespace {

std::u16string ConvertPathToUTF16(const std::string& path) {
  // Per RFC 2640, FTP servers should use UTF-8 or its proper subset ASCII,
  // but many old FTP servers use legacy encodings. Try UTF-8 first.
  if (base::IsStringUTF8(path))
    return base::UTF8ToUTF16(path);

  // Try detecting the encoding. The sample is rather small though, so it may
  // fail.
  std::string encoding;
  if (base::DetectEncoding(path, &encoding) && encoding != "US-ASCII") {
    std::u16string path_utf16;
    if (base::CodepageToUTF16(path, encoding.c_str(),
                              base::OnStringConversionError::SUBSTITUTE,
                              &path_utf16)) {
      return path_utf16;
    }
  }

  // Use system native encoding as the last resort.
  return base::WideToUTF16(base::SysNativeMBToWide(path));
}

}  // namespace

scoped_refptr<SharedBuffer> GenerateFtpDirectoryListingHtml(
    const KURL& url,
    const SharedBuffer* input) {
  const GURL gurl = GURL(url);
  scoped_refptr<SharedBuffer> output = SharedBuffer::Create();
  base::UnescapeRule::Type unescape_rules =
      base::UnescapeRule::SPACES |
      base::UnescapeRule::URL_SPECIAL_CHARS_EXCEPT_PATH_SEPARATORS;
  std::string unescaped_path =
      base::UnescapeURLComponent(gurl.path(), unescape_rules);
  const std::string header =
      net::GetDirectoryListingHeader(ConvertPathToUTF16(unescaped_path));
  output->Append(base::span<const char>(header.data(), header.size()));

  // If this isn't top level directory (i.e. the path isn't "/",)
  // add a link to the parent directory.
  if (gurl.path().length() > 1) {
    const std::string link = net::GetParentDirectoryLink();
    output->Append(base::span<const char>(link.data(), link.size()));
  }

  std::string flatten;
  for (const auto& span : *input) {
    flatten.append(span.data(), span.size());
  }

  std::vector<net::FtpDirectoryListingEntry> entries;
  int rv = net::ERR_NOT_IMPLEMENTED;
#if !BUILDFLAG(DISABLE_FTP_SUPPORT)
  rv = net::ParseFtpDirectoryListing(flatten, base::Time::Now(), &entries);
#endif
  if (rv != net::OK) {
    const std::string script = "<script>onListingParsingError();</script>\n";
    output->Append(base::span<const char>(script.data(), script.size()));
    return output;
  }
  for (const net::FtpDirectoryListingEntry& entry : entries) {
    // Skip the current and parent directory entries in the listing.
    // net::GetParentDirectoryLink() takes care of them.
    if (base::EqualsASCII(entry.name, ".") ||
        base::EqualsASCII(entry.name, ".."))
      continue;

    bool is_directory =
        (entry.type == net::FtpDirectoryListingEntry::DIRECTORY);
    std::string entry_string = net::GetDirectoryListingEntry(
        entry.name, entry.raw_name, is_directory,
        entry.type == net::FtpDirectoryListingEntry::FILE
            ? std::make_optional<base::ByteSize>(base::as_unsigned(entry.size))
            : std::nullopt,
        entry.last_modified);
    output->Append(
        base::span<const char>(entry_string.data(), entry_string.size()));
  }

  return output;
}

}  // namespace blink
