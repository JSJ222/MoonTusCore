///|
test "parse canonical non-negative integers" {
  guard parse_non_negative_i64("upload-offset", "0") is Ok(zero) else {
    fail("zero should parse")
  }
  assert_eq(zero, 0L)
  guard parse_non_negative_i64("upload-offset", "42") is Ok(answer) else {
    fail("42 should parse")
  }
  assert_eq(answer, 42L)
  guard parse_non_negative_i64("upload-offset", "9223372036854775807")
    is Ok(maximum) else {
    fail("Int64 maximum should parse")
  }
  assert_eq(maximum, 9223372036854775807L)
}

///|
test "reject signs fractions and overflow" {
  inspect(parse_non_negative_i64("x", "-1") is Err(_), content="true")
  inspect(parse_non_negative_i64("x", "+1") is Err(_), content="true")
  inspect(parse_non_negative_i64("x", "1.0") is Err(_), content="true")
  inspect(
    parse_non_negative_i64("x", "9223372036854775808") is Err(_),
    content="true",
  )
}

///|
test "checked addition rejects overflow" {
  guard checked_add_i64(4L, 5L) is Ok(nine) else {
    fail("small addition should succeed")
  }
  assert_eq(nine, 9L)
  inspect(checked_add_i64(9223372036854775807L, 1L) is Err(_), content="true")
}

///|
test "content length must match body" {
  let valid = request(
    "PATCH",
    "/files/a",
    headers=Headers::empty().add("Content-Length", "3"),
    body=b"abc",
  )
  guard require_content_length(valid) is Ok(three) else {
    fail("matching length should succeed")
  }
  assert_eq(three, 3)
  let invalid = request(
    "PATCH",
    "/files/a",
    headers=Headers::empty().add("Content-Length", "2"),
    body=b"abc",
  )
  inspect(require_content_length(invalid) is Err(_), content="true")
}
