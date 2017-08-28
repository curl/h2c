# h2c
headers 2 curl. Provided a set of HTTP request headers, output the curl command line for generating that set.

    $ cat test
    HEAD  / HTTP/1.1
    Host: curl.haxx.se
    User-Agent: moo
    Shoesize: 12

    $ ./h2c.pl < test
    curl --head --http1.1 --header Accept: --user-agent "moo" --header "Shoesize: 12" https://curl.haxx.se/

