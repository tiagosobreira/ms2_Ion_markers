$abpp_mod = "DBIA";
@tsvs = `ls -1 combined/txt/evidence.txt`;
@ls = `ls -1 *.mgf`;


chomp(@tsvs);
chomp(@ls);

for $tsv (@tsvs){
    open (TSV,$tsv);
    while (<TSV>){
	chop;
	chop;
	chomp;
	@aux = split(/\t/);

	$file = $aux[18];
	$scan = $aux[49];
	
	if($aux[2] =~ m/$abpp_mod/){
	    $ABPP2scan{$file}{$scan} = 1;
	}
	else{
	    $PSM2scan{$file}{$scan} = 1;
	}
    }
    close(TSV);
}
    

$skip_mz{126.12} = 1;
$skip_mz{127.12} = 1;
$skip_mz{127.13} = 1;
$skip_mz{128.12} = 1;
$skip_mz{128.13} = 1;
$skip_mz{129.13} = 1;
$skip_mz{130.13} = 1;
$skip_mz{130.14} = 1;
$skip_mz{131.13} = 1;
$skip_mz{131.14} = 1;
$skip_mz{132.14} = 1;
$skip_mz{133.14} = 1;
$skip_mz{133.15} = 1;
$skip_mz{134.14} = 1;
$skip_mz{134.15} = 1;
$skip_mz{135.15} = 1;



for $mgf_file (@ls){
    print stderr "$mgf_file\n";

   
    open (MGF,$mgf_file);

    while(<MGF>){
	chomp;
	if ($_ =~ m/TITLE=(.*)\.(\d+)\.\d+\./){
	    $file = $1;
	    $scan = $2;

	    $all_files{$file} = 1;
	    
	    $ctrl_ABPP = 0;
	    $ctrl_PSM = 0;

	    %tmp_intensity = ();
	    $max_intensity = 0;
	    
	    if (exists $ABPP2scan{$file}{$scan}){
		$ctrl_ABPP = 1;
		$all_scan{$file}{$scan} = 1;
		$total_number_scan++;
	    }
	    elsif(exists $PSM2scan{$file}{$scan}){
		$ctrl_PSM = 1;
		$all_scan{$file}{$scan} = 1;
		$total_number_scan++;
	    }
	}


	if($_=~ m/^([\d\.]+)\s([\d\.]+)/){
	    $mz = $1;
	    $intensity = $2;

	    $max_intensity = $intensity if($max_intensity < $intensity);
	    $mz = (int($mz*100))/100;
	    next if (exists $skip_mz{$mz});
	    
	    if (exists $tmp_intensity{$mz}){
		if($tmp_intensity{$mz} < $intensity){
		    $tmp_intensity{$mz} = $intensity;
		}
	    }
	    else{
		$tmp_intensity{$mz} = $intensity;
	    }
	    
	}


	if($_ =~ m/END IONS/){
	    for my $mz (sort keys %tmp_intensity){
		if ($ctrl_ABPP == 1){
		    if($tmp_intensity{$mz}/$max_intensity > 0.1){
			$all_mz{$mz} += 1;
			$data_int{$file}{$scan}{$mz} = sprintf("%.2f", $tmp_intensity{$mz}/$max_intensity);
		    }
		}
		elsif($ctrl_PSM == 1){
		    if($tmp_intensity{$mz}/$max_intensity > 0.1){
			$all_mz{$mz} += 1;
			$not_data_int{$file}{$scan}{$mz} = sprintf("%.2f", $tmp_intensity{$mz}/$max_intensity);
		    }
		}
	    }
	}
    }
    close(MGF);

}


print "File Scan\tClass";
for $mz (sort {$a<=>$b} keys %all_mz){
    if ($all_mz{$mz} > $total_number_scan*0.05){
	print "\t$mz";
	$approved_mz{$mz} = 1;
    }
}
print "\n";
#exit;

for $file (sort keys %all_files){
    for $scan(sort {$a<=>$b} keys %{$all_scan{$file}}){
	if (exists $data_int{$file}{$scan}){
	    print "$file $scan\t$abpp_mod";
	    
	    for $mz (sort {$a<=>$b} keys %approved_mz){
		if ((exists $data_int{$file}{$scan}{$mz}) && ($data_int{$file}{$scan}{$mz} > 0)){
		    print "\t$data_int{$file}{$scan}{$mz}";
		}
		else{
		    print "\t0";
		}
	    }
	    print "\n";
	    
	}
	else{
	    print "$file $scan\tNOT";
	    for $mz (sort {$a<=>$b} keys %approved_mz){
		if ((exists $not_data_int{$file}{$scan}{$mz}) && ($not_data_int{$file}{$scan}{$mz} > 0)){
		    print "\t$not_data_int{$file}{$scan}{$mz}";
		}
		else{
		    print "\t0";
		}
	    }
	    print "\n";
	}
	
    }
}
