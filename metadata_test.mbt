///|
test "metadata parses values and valueless keys" {
  match
    parse_upload_metadata(
      "filename aGVsbG8udHh0,filetype dGV4dC9wbGFpbg==,empty",
      TusLimits::strict_test(),
    ) {
    Err(_) => fail("valid metadata should parse")
    Ok(entries) => {
      assert_eq(entries.length(), 3)
      assert_eq(metadata_get(entries, "filename"), Some(b"hello.txt"))
      assert_eq(metadata_get(entries, "empty"), Some(b""))
      inspect(
        serialize_upload_metadata(entries),
        content="filename aGVsbG8udHh0,filetype dGV4dC9wbGFpbg==,empty",
      )
    }
  }
}

///|
test "metadata rejects repeated key" {
  match parse_upload_metadata("name YQ==,name Yg==", TusLimits::strict_test()) {
    Err(error) => assert_eq(error.kind, DuplicateMetadataKey)
    Ok(_) => fail("duplicate metadata key must fail")
  }
}

///|
test "metadata rejects malformed separators" {
  for value in [",name YQ==", "name  YQ==", "name ", "bad key YQ=="] {
    match parse_upload_metadata(value, TusLimits::strict_test()) {
      Err(error) => assert_eq(error.kind, InvalidMetadata)
      Ok(_) => fail("malformed metadata must fail")
    }
  }
}

///|
test "metadata rejects invalid encoded values" {
  match parse_upload_metadata("name not-base64", TusLimits::strict_test()) {
    Err(error) => assert_eq(error.kind, InvalidBase64)
    Ok(_) => fail("invalid Base64 must fail")
  }
}

///|
test "metadata enforces entry count" {
  let limits = { ..TusLimits::strict_test(), max_metadata_entries: 2, }
  match parse_upload_metadata("a,b,c", limits) {
    Err(error) => assert_eq(error.kind, TooManyMetadataEntries)
    Ok(_) => fail("entry count overflow must fail")
  }
}

///|
test "metadata enforces wire byte budget" {
  let limits = { ..TusLimits::strict_test(), max_metadata_bytes: 5, }
  match parse_upload_metadata("longer", limits) {
    Err(error) => assert_eq(error.kind, MetadataTooLarge)
    Ok(_) => fail("wire size overflow must fail")
  }
}

///|
test "metadata constructor validates keys" {
  match metadata_entry("display-name", b"MoonTusCore") {
    Ok(entry) => inspect(entry.encoded_value, content="TW9vblR1c0NvcmU=")
    Err(_) => fail("valid key must construct")
  }
  match metadata_entry("bad,key", b"x") {
    Err(error) => assert_eq(error.kind, InvalidMetadata)
    Ok(_) => fail("comma in key must fail")
  }
}
