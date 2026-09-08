# MoonTusCore

Framework-neutral tus 1.0 resumable upload protocol decisions for MoonBit.

```moonbit nocheck
let engine = @tuscore.Engine::memory()
let response = engine.handle(@tuscore.options_request())
inspect(response.status, content="204")
```

