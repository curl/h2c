# h2c
headers 2 curl. Provided a set of HTTP request headers, output the curl command line for generating that set.

    $ cat test
    HEAD  / HTTP/1.1
    Host: curl.se
    User-Agent: moo
    Shoesize: 12

    $ ./h2c < test
    curl --head --http1.1 --header Accept: --user-agent "moo" --header "Shoesize: 12" https://curl.se/

or a more complicated one:

    $ cat test2
    PUT /this is me HTTP/2
    Host: curl.se
    User-Agent: moo on you all
    Shoesize: 12
    Cookie: a=12; b=23
    Content-Type: application/json
    Content-Length: 57

    {"I do not speak": "jason"}
    {"I do not write": "either"}

    $ ./h2c < test2
    curl --http2 --header Accept: --user-agent "moo on you all" --header "shoesize: 12" --cookie "a=12; b=23" --header "content-type: application/json" --data-binary "{\"I do not speak\": \"jason\"} {\"I do not write\": \"either\"}" --request PUT "https://curl.se/this is me"

multipart!

    $ cat multipart
    POST /upload HTTP/1.1
    Host: example.com
    User-Agent: curl/7.55.0
    Accept: */*
    Content-Length: 1236
    Expect: 100-continue
    Content-Type: multipart/form-data; boundary=------------------------2494bcbbb6e66a98

    --------------------------2494bcbbb6e66a98
    Content-Disposition: form-data; name="name"

    moo
    --------------------------2494bcbbb6e66a98
    Content-Disposition: form-data; name="file"; filename="README.md"
    Content-Type: application/octet-stream

    contents

    --------------------------2494bcbbb6e66a98--

    $ ./h2c < multipart
    curl --http1.1 --user-agent "curl/7.55.0" --form name=moo --form file=@README.md https://example.com/upload

authentication

    $ cat basic
    GET /index.html HTTP/2
    Host: example.com
    Authorization: Basic aGVsbG86eW91Zm9vbA==
    Accept: */*

    $ ./h2c < basic
    curl --http2 --header User-Agent: --user "hello:youfool" https://example.com/index.html
