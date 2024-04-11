@raws = `find ./ ! -type d -name "*.raw"`;
chomp (@raws);

for (@raws){

    chomp;

    $_ =~ m/.*\/(.*.raw)/;
    $rawfile = $1;
    print "$rawfile\n";

    $rawfile =~ m/(.*).raw/;
    $rawfilename = $1;

    next if (exists $processed{$rawfilename});
    $processed{$rawfilename} = 1;

    if (! -e "$rawfilename.mgf"){

	print "cp \"$_\" .\n";
        system "cp \"$_\" .";
	
	print "/usr/bin/docker run --rm -e WINEDEBUG=-all -v /home/tiago.sobreira/Ion_marker:/data chambm/pwiz-skyline-i-agree-to-the-vendor-licenses wine msconvert $rawfile\n";
	system "/usr/bin/docker run --rm -e WINEDEBUG=-all -v /home/tiago.sobreira/Ion_marker:/data chambm/pwiz-skyline-i-agree-to-the-vendor-licenses wine msconvert --mgf $rawfile";
    }
    else{
	#print "$rawfile\n";
    }

    #exit;
}

