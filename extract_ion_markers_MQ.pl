use Parallel::ForkManager;
my $pm = Parallel::ForkManager->new(6);

$abpp_mod = "DBIA";

@tsvs = `ls -1 combined/txt/evidence.txt`;
chomp(@tsvs);

for $tsv (@tsvs){
    open (TSV,$tsv);
    while (<TSV>){
	chop;
	chop;
	chomp;
	@aux = split(/\t/);

	$file = $aux[18];
	$scan = $aux[49];


	#print "$aux[2]\t{$file}\t{$scan}\n";
	if($aux[2] =~ m/$abpp_mod/){
	    $ABPP2scan{$file}{$scan} = 1;
	}
	else{
	    $PSM2scan{$file}{$scan} = 1;
	}
    }
    close(TSV);
}
    
#exit;

$pm->run_on_finish( sub {
    my ($pid, $exit_code, $ident, $exit_signal, $core_dump, $data_structure_reference) = @_;

    $data_tmp = $data_structure_reference->{data};
    %data_tmp = %$data_tmp;
    
    $data_int_tmp = $data_structure_reference->{data_int};
    %data_int_tmp = %$data_int_tmp;
    
    $not_data_tmp = $data_structure_reference->{not_data};
    %not_data_tmp = %$not_data_tmp;
    
    $not_data_int_tmp = $data_structure_reference->{not_data_int};
    %not_data_int_tmp = %$not_data_int_tmp;

    $yes_count += $data_structure_reference->{yes_count};
    $no_count += $data_structure_reference->{no_count};

    
    for $mz (keys %data_tmp){
	$data{$mz} += $data_tmp{$mz};
	$data_int{$mz} += $data_int_tmp{$mz};
    }

    for $mz (keys %not_data_tmp){
	$not_data{$mz} += $not_data_tmp{$mz};
	$not_data_int{$mz} += $not_data_int_tmp{$mz};
    }
    
});


@ls = `ls -1 *.mgf`;
chomp(@ls);

DATA_LOOP:
for $mgf_file (@ls){
    print stderr "$mgf_file\n";

    my $pid = $pm->start and next DATA_LOOP;
    my ($data,$data_int,$not_data,$not_data_int,$yes_count_tmp,$no_count_tmp) = process($mgf_file);
    $pm->finish(0, {data => $data, data_int => $data_int, not_data => $not_data, not_data_int => $not_data_int,yes_count => $yes_count_tmp,no_count => $no_count_tmp});
}
$pm->wait_all_children;





open (OUT, ">$abpp_mod\_stats.tsv");
print OUT "mz\tABPP count\tNot ABPP count\tDiffence count\tABPP average intensity\tNot ABPP average intensity\tDifference intensity\n";

for $mz (sort {$a <=> $b} keys %data){
    $ABPP = $data{$mz}/$yes_count;
    $Not = $not_data{$mz}/$no_count;
    $diff = $ABPP - $Not;

    $ABPP_int = $data_int{$mz}/$yes_count;
    $Not_int = $not_data_int{$mz}/$no_count;
    $diff_int = $ABPP_int - $Not_int;
	
    print OUT "$mz\t$ABPP\t$Not\t$diff\t$ABPP_int\t$Not_int\t$diff_int\n";
}
close(OUT);


sub process {

    $mgf_file = shift;
    my %data = ();
    my %data_int = ();
    my %not_data = ();
    my %not_data_int = ();
    my $yes_count = 0;
    my $no_count = 0;
    open (MGF,$mgf_file);

    while(<MGF>){
	chomp;
	if ($_ =~ m/TITLE=(.*)\.(\d+)\.\d+\./){
	    $file = $1;
	    $scan = $2;

	    $ctrl_ABPP = 0;
	    $ctrl_PSM = 0;

	    %tmp_intensity = ();
	    $max_intensity = 0;
	    
	    if (exists $ABPP2scan{$file}{$scan}){
		$ctrl_ABPP = 1;
		$yes_count++;
	    }
	    elsif(exists $PSM2scan{$file}{$scan}){
		$ctrl_PSM = 1;
		$no_count++;
	    }
	    
	}


	if($_=~ m/^([\d\.]+)\s([\d\.]+)/){
	    $mz = $1;
	    $intensity = $2;

	    $max_intensity = $intensity if($max_intensity < $intensity);
	    $mz = (int($mz*100))/100;
	    
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
			$data{$mz} += 1;
			$data_int{$mz} += $tmp_intensity{$mz}/$max_intensity;
		    }
		}
		elsif($ctrl_PSM == 1){
		    if($tmp_intensity{$mz}/$max_intensity > 0.1){
			$not_data{$mz} += 1;
			$not_data_int{$mz} += $tmp_intensity{$mz}/$max_intensity;
		    }
		}
	    }
	}
    }
    close(MGF);
    return(\%data,\%data_int,\%not_data,\%not_data_int,$yes_count,$no_count);
}

