# h2c
headers 2 curl. Provided a set of HTTP request headers, output the curl command line for generating that set.

    $ cat test
    HEAD  / HTTP/1.1
    Host: curl.haxx.se
    User-Agent: moo
    Shoesize: 12

    $ ./h2c.pl < test
    curl --head --http1.1 --header Accept: --user-agent "moo" --header "Shoesize: 12" https://curl.haxx.se/

or a more complicated one:

    $ cat test2
    PUT /this is me HTTP/2
    Host: curl.haxx.se
    User-Agent: moo on you all
    Shoesize: 12
    Cookie: a=12; b=23
    Content-Type: application/json
    Content-Length: 6

    {"I do not speak": "jason"}
    {"I do not write": "either"}

    $ ./h2c.pl < test2
    curl --http2 --header Accept: --user-agent "moo on you all" --header "shoesize: 12" --cookie "a=12; b=23" --header "content-type: application/json" --data-binary "{\"I do not speak\": \"jason\"} {\"I do not write\": \"either\"}" --request PUT "https://curl.haxx.se/this is me"
