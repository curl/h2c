#!/usr/bin/perl

my @raw;
my $state; # 0 is request-line, 1-headers, 2-body
while(<STDIN>) {
    chomp;
    push @raw, $_;
    if(!$state) {
        if($_ =~ /([^ ]*) +(.*) +(HTTP\/.*)/) {
            $method = $1;
            $path = $2;
            $http = $3;
        }
        else {
            $error="bad request-line";
            last;
        }
        $state++;
    }
    elsif(1 == $state) { 
        if($_ =~ /([^:]*): *(.*)/) {
            $header{$1}=$2;
        }
        elsif(!length($_)) {
            # body time
            $state++;
        }
    }
}

my $usesamehttpversion = 1;
my $disableheadersnotseen = 1;

if(!$header{'Host'}) {
    $error = "No Host: header makes it impossible to tell URL\n";
}

if($error) {
    print "Error: $error\n";
}
else {
    my $httpver="";
    my $disabledheaders="";
    if($method eq "HEAD") {
        $usemethod = "--head ";
    }
    if($usesamehttpversion) {
        if($http eq "HTTP/1.1") {
            $httpver = "--http1.1 ";
        }
    }
    if($disableheadersnotseen) {
        if(!$header{'Accept'}) {
            $disabledheaders .= "--header Accept: ";
        }
        if(!$header{'User-Agent'}) {
            $disabledheaders .= "--header User-Agent: ";
        }
    }
    foreach my $h (keys %header) {
        if($h eq "Host") {
            # We use Host: for the URL creation
        }
        else {
            my $opt = sprintf("--header \"%s: ", $h);
            if($h eq "User-Agent") {
                $opt = "--user-agent \"";
            }
            $addedheaders .= sprintf("%s%s\" ", $opt, $header{$h});
        }
    }
    printf "curl %s%s%s%shttps://%s%s\n",
        $usemethod,
        $httpver,
        $disabledheaders,
        $addedheaders,
        $header{'Host'}, $path;
}
