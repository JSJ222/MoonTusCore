# Contributing

Keep protocol semantics independent of HTTP frameworks and persistent storage.
New behavior needs success, boundary, rejection, and no-mutation tests.

~~~bash
moon fmt --check
moon check --target all --deny-warn
moon test --target all --deny-warn
moon build --target all
~~~

Document protocol sources and licenses. Do not advertise an extension until its
state transitions and rejection behavior are implemented and tested.
