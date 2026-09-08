///|
test "base64 encodes canonical vectors" {
  inspect(encode_base64(b""), content="")
  inspect(encode_base64(b"f"), content="Zg==")
  inspect(encode_base64(b"fo"), content="Zm8=")
  inspect(encode_base64(b"foo"), content="Zm9v")
  inspect(encode_base64(b"foobar"), content="Zm9vYmFy")
}

///|
test "base64 round trips binary bytes" {
  let source = Bytes::from_array([0, 1, 2, 127, 128, 254, 255])
  let encoded = encode_base64(source)
  match decode_base64(encoded, 7) {
    Ok(decoded) => assert_eq(decoded, source)
    Err(_) => fail("canonical binary value should decode")
  }
}

///|
test "base64 rejects missing padding" {
  match decode_base64("Zg", 8) {
    Err(error) => assert_eq(error.kind, InvalidBase64)
    Ok(_) => fail("missing padding must fail")
  }
}

///|
test "base64 rejects misplaced padding" {
  for value in ["=m9v", "Zm=v", "Zg==AAAA"] {
    match decode_base64(value, 16) {
      Err(error) => assert_eq(error.kind, InvalidBase64)
      Ok(_) => fail("invalid padding must fail")
    }
  }
}

///|
test "base64 rejects non-zero tail bits" {
  for value in ["Zh==", "Zm9="] {
    match decode_base64(value, 16) {
      Err(error) => assert_eq(error.kind, InvalidBase64)
      Ok(_) => fail("non-canonical tail bits must fail")
    }
  }
}

///|
test "base64 enforces decoded byte budget" {
  match decode_base64("Zm9v", 2) {
    Err(error) => assert_eq(error.kind, MetadataTooLarge)
    Ok(_) => fail("budget overflow must fail")
  }
}
