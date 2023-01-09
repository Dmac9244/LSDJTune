#!/usr/bin/perl

# LSDJ microtuning script
# JHL (abrasive) 2009 (Updated by Dmac9244 2020)
# tested with LSDJ 8.7.1

#use Data::Dumper;
use File::Copy;

print "lsdj_tune 1.5.1 -- for LSDJ versions 8-9 -- abrasive 24/3/2009 (Updated 6/25/2020)\n";

# Helps eliminate error in frequency table by trying to find a register which more closely matches the frequency
sub roundreg($$) { #How to declare?
    my ($reg, $freq) = @_;
    return minfreq(minfreq($reg-1, $reg, $freq), $reg+1, $freq);
}

# Finds and returns the # of the register closest to the desired frequency.
sub minfreq($$) {
    my ($reg1, $reg2, $freq) = @_;
    return abs((131072/(2048-$reg1)) - $freq) < abs((131072/(2048-$reg2)) - $freq) ? $reg1 : $reg2;
}

# Converts a list of frequencies to a list of registers to be written to the ROM
sub freq2reg {
    my ($freq, $reg);
    my @regs;
    while ($freq = shift) {
        $reg = int((2048-(131072/$freq))+.5);
	#print("$reg\n");

	#$reg = roundreg($reg, $freq);

        if ($reg <= 0) {
            $reg = 1;
            print "Warning: frequency too low ($freq Hz)\n";
        }
        if ($reg >= 2048) {
            $reg = 2047;
            print "Warning: frequency too high ($freq Hz)\n";
        }
        push @regs, $reg;
    }
    return @regs;
}

# Converts a list of registers to a list of frequencies (used for tuning chart)
sub reg2freq {
    my $reg;
    my @freqs;
    while ($reg = shift) {
        push @freqs, 131072/(2048-$reg);
    }
    return @freqs;
}

use constant SGB_DETUNE => 4194304/4295454;

# Seemingly unused, calculates registers for SGB as opposed to GB
sub freq2sgb {
    my @f = @_;
    $_ *= SGB_DETUNE foreach(@f);
    return freq2reg(@f);
}

# Calculates error of frequency as calculated by register compared to frequency as calculated by the script in Hz and cents
sub tuneerr($$) {
    my ($dfreqs, $afreqs) = @_;
    my (@cent_err, @hz_err);
    my $i;
    for ($i=0; $i<=$#{$dfreqs}; $i++) {
        $hz_err[$i] = $afreqs->[$i]-$dfreqs->[$i];
        $cent_err[$i] = 1200*log( $afreqs->[$i]/$dfreqs->[$i] )/log(2);
    }
    return (\@cent_err, \@hz_err);
}

# ?
my @note_names = ('C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B');
sub nam2num {
    my $name = shift;
    return -1 unless $name =~ /^([A-G]|[ACDFG]\#) *([3-9AB])$/i;
    my $octave = hex($2)-3;
    for (my $i=0; $i<=$#note_names; $i++) {
        if ($note_names[$i] eq uc($1)) {
            return $i+$octave*12;
        }
    }
    return -1;
}
sub num2nam {   # for display only
    my $num = shift;
    return '   ' if ($num<0) || ($num >= 108);
    my $oct = int($num/12);
    my $note = $num % 12;
    return sprintf("%-2s%1X", $note_names[$note], $oct+3);
}

# Calculates the min of two numbers
sub min($$) {
    my ($a, $b) = @_;
    return $a<$b ? $a : $b;
}

# Generates an array of frequencies from a list of cent intervals
sub rep_cent_tune {
    my ($basenote, $basefreq, $centarr, $namelist) = @_;
    my $looplen = $#{$centarr};

    my (@cents, @freqs, @names, @nameloop);
    my $notes_remain = 108;
    my $centrun = 0;
    my $centstep = $centarr->[$#{$centarr}];
    my $octave = 0;

    if (defined($namelist)) {
        @nameloop = split(/,/, $namelist);
        die("Wrong number of note names, expected $looplen") if ($#nameloop+1 != $looplen); # XXX allow ET/cstep naming && ($looplen!=1);
    }

    my $offset = $basenote % $looplen;

    if ($offset) {
        foreach (($looplen-$offset)..($looplen-1)) {
            push @names, sprintf("%-2s%X", $nameloop[$_], $octave) if defined($namelist);
            push @cents, $centarr->[$_];
        }
        $notes_remain -= $offset;
        $centrun += $centstep;
    }
    $octave++;

    while ($notes_remain>0) {
        for (my $i=0; $i<min($looplen, $notes_remain); $i++) {
            push @cents, $centarr->[$i]+$centrun;
            push @names, sprintf("%-2s%X", $nameloop[$i], $octave) if defined($namelist);
        }
        $centrun += $centstep;
        $octave++;
        $notes_remain -= min($looplen, $notes_remain);
    }

    my $base_cent = $cents[$basenote];
    print("@cents\n");
    foreach (@cents) {
        $freqoffset = $basefreq * 2**(($_-$base_cent)/1200);
        print("$freqoffset\n");
        push @freqs, $basefreq * 2**(($_-$base_cent)/1200);
    }
    return (\@freqs, $#names ? \@names : undef);
}

# A copy of the above subroutine I was playing with
sub rep_cent_tune_2 {
  my ($basenote, $basefreq, $centarr, $namelist) = @_; #$centarr is an array of cent offsets starting at 0.
  my $looplen = $#{$centarr};

  my (@cents, @freqs, @names, @nameloop);
  my $notes_remain = 108;
  my $centrun = 0;
  my $centstep = $centarr->[$#{$centarr}];
  my $octave = 0;

  if (defined($namelist)) {
      @nameloop = split(/,/, $namelist);
      die("Wrong number of note names, expected $looplen") if ($#nameloop+1 != $looplen); # XXX allow ET/cstep naming && ($looplen!=1);
  }

  my $offset = $basenote % $looplen; # Offset so that while basenote is not C, basenote frequency remains intact?

  if ($offset) { # Offsets the centarr if the base note is not C?
      foreach (($looplen-$offset)..($looplen-1)) {
          push @names, sprintf("%-2s%X", $nameloop[$_], $octave) if defined($namelist);
          push @cents, $centarr->[$_];
      }
      $notes_remain -= $offset;
      $centrun += $centstep;
  }
  $octave++; # Why this?

  while ($notes_remain>0) {
      for (my $i=0; $i<min($looplen, $notes_remain); $i++) {
          push @cents, $centarr->[$i]+$centrun;
          push @names, sprintf("%-2s%X", $nameloop[$i], $octave) if defined($namelist);
      }
      $centrun += $centstep;
      $octave++;
      $notes_remain -= min($looplen, $notes_remain);
  }

  my $base_cent = $cents[$basenote]; # And I suppose this is what uses the list of cent offsets to determine a frequency.
  foreach (@cents) {
      print("@cents\n");
      push @freqs, $basefreq * 2**(($_-$base_cent)/1200);
  }
  return (\@freqs, $#names ? \@names : undef);
}


# Prings a tuning table which demonstrates the error of the written registers compared to the intended frequencies
sub print_tuning {
    my ($freqs, $regs, $names) = @_;
    my @gbfreqs = reg2freq(@{$regs});
    my ($cent_err, $hz_err) = tuneerr($freqs, \@gbfreqs);
           #C 3    65.41  002C    65.41      -0.00  -0.03
    print "       Freq   Reg    Actual   Error\n";
    print "        (hz)           (hz)         Hz    cent\n";

    for (my $i=0; $i<108; $i++) {
        if ($#{$names}>0) {
            printf "%-3.3s ",  $names->[$i];
        } else {
            print num2nam($i) . " ";
        }
        printf("%8.2f  ", $freqs->[$i]);
        printf("%04X ", $regs->[$i]);
        printf("%8.2f ", $gbfreqs[$i]);
print "  ";
        printf("%+8.2f %+7.2f", $hz_err->[$i], $cent_err->[$i]);
        print "\n";
    }
}

# Uses the beginning of the frequency and note name tables to find them wherever they may be in an LSDJ ROM.
sub find_tables {
    my $file = shift;
    my ($tune_loc, $name_loc, $i);
    # these are unique in the ROM... as of 3.9.9
    # we assume SGB table follows freq table for now
    my @tuning_head = (0x2c, 0x00, 0x9d, 0x00, 0x07, 0x01, 0x6b, 0x01, 0xc9, 0x01);
    my @name_head = (0x43, 0x20, 0x32, 0x43, 0x23, 0x32, 0x44, 0x20, 0x32);
    for (my $offset = 0; $offset <= 0xAAAAA; $offset++) {
        if (!$tune_loc) {
            seek $file, $offset, SEEK_SET;
            for ($i=0; $i<=$#tuning_head; $i++) {
                last unless $tuning_head[$i]==ord(getc($file));
            }
            $tune_loc = $offset if ($i>$#tuning_head);
        }
        if (!$name_loc) {
            seek $file, $offset, SEEK_SET;
            for ($i=0; $i<=$#name_head; $i++) {
                last unless $name_head[$i]==ord(getc($file));
            }
            $name_loc = $offset if ($i>$#name_head);
        }
        last if ($name_loc && $tune_loc);
    }
    die("Could not find tuning table in ROM!") unless $tune_loc;
    die("Could not find note name table in ROM!") unless $name_loc;
    return ($tune_loc, $name_loc);
}

# Prints usage
sub usage {
    print <<USAGE
Usage:
    Pregenerated tuning:
        --freq-table <filename>     for 108 freqs, one per line
                                        starting with C3
    Generated tuning:
  -b    --base <note> <freq>        define the fixed-point
                                        (required for generated tuning)
                                        note may be specified by number
                                        (0-107) or LSDJ name (C3-BB)
  -e    --et N              N-tone equal temperament
        --cstep N           equal steps of N cents
        --cents X,Y,Z       specify a series in cents
                                eg. 0,100,200...1200 is 12-tone ET
        --ratio X,Y,Z       ratio tuning
                                eg. 1,81/80,33/32,2

    Note naming:
        --name-file <filename>
                            read 108 lines of note names
        --names AAA,BBB     name a repeating series (for --cents,--ratio)

    ROM handling:
  -r    --rom <romfile>     the LSDJ ROM to use as source
  -o    --out <outfile>     file to write the tuned ROM into

    Misc:
  -q    --quiet             don't print the tuning table
USAGE
        #--sgb               print the SGB tuning table
;
exit(1);
#confess("No!");
}

# Takes and parses the arguments passed along from the command line.
sub eat_cmdline {
    my $method = undef;
    my $basenote = undef;
    my $basefreq = undef;
    my $nparam;
    my $outfile = undef;
    my $infile = undef;
    my $quiet = 0;
    my $rom = undef;
    my $namefile = undef;
    my $names = undef;

    while ($_=shift) {
        (/^--et$/ || /^-e$/) && do {
            usage() if defined($method);
            $method = 'et';
            $nparam = shift;
            usage() unless $nparam>0;
            next;
            };
        (/^--cstep$/) && do {
            usage() if defined($method);
            $method = 'cstep';
            $nparam = shift;
            usage() unless $nparam>0;
            next;
            };
        (/^--fstep$/) && do {
            usage() if defined($method);
            $method = 'fstep';
            $nparam = shift;
            usage() unless $nparam>0;
            next;
            };
        (/^--cents$/) && do {
            usage() if defined($method);
            $method = 'cents';
            $nparam = shift;
            usage() unless $nparam;
            next;
            };
        (/^--ratio$/) && do {
            usage() if defined($method);
            $method = 'ratio';
            $nparam = shift;
            usage() unless $nparam;
            next;
            };
        (/^--base$/ || /^-b$/) && do {
            my $bn = shift;
            if ($bn =~ /^\d/) {
                $basenote = $bn;
            } else {
                $basenote = nam2num($bn);
            }
            usage() if ($basenote<0) || ($basenote >= 108);
            $basefreq = shift;
            usage() if $basefreq <= 0;
            next;
            };
        (/^--freq-table$/) && do {
            usage() if defined($method);
            $method = 'ftable';
            $infile = shift;
            next;
            };
        (/^--out$/ || /^-o$/) && do {
            $outfile = shift;
            next;
            };
        (/^--quiet$/ || /^-q$/) && do {
            $quiet = 1;
            next;
            };
        (/^--names$/) && do {
            $names = shift;
            next;
            };
        (/^--name-file$/) && do {
            $namefile = shift;
            next;
            };
        (/^--rom$/ || /^-r$/) && do {
            $rom = shift;
            next;
            };
        usage();
    }
    usage() if defined($names) && defined($namefile);
    usage() if $method ne 'ftable' && !defined($basefreq);
    usage() if defined($outfile) && !defined($rom);
    return {'method' => $method,
            'nparam' => $nparam,
            'infile' => $infile,
            'outfile' => $outfile,
            'basenote' => $basenote,
            'basefreq' => $basefreq,
            'namefile' => $namefile,
            'names' => $names,
            'rom' => $rom,
            'quiet' => $quiet};
}

# main
my $args = eat_cmdline(@ARGV);

my $method = $args->{method};
my @freqs = ();
my @names;

if ($args->{namefile}) {
    open FIN, '<', $args->{namefile} || die("Could not open name table!");
    for (<FIN>) {
        /^(..?.?)/ && do { push @names, $1;};
    }
    close FIN;
    my $nnames = $#names+1;
    die ("Name table contains $nnames entries, expected 108!") if ($nnames != 108);
}

if ($method eq 'ftable') {
    open FIN, '<', $args->{infile} || die("Could not open input file!");
    for (<FIN>) {
        /([0-9]+(\.[0-9]+)?)/ && do {
            push @freqs, $1;
            }
    }
    close FIN;
    my $nfreqs = $#freqs+1;
    die ("File contains $nfreqs entries, expected 108!") if ($nfreqs != 108);
} else {
    my @result;
    if ($method eq 'fstep') {
        die("not implemented");
    } elsif ($method eq 'cstep') {
        @result = rep_cent_tune($args->{basenote},
                               $args->{basefreq},
                               [0, $args->{nparam}],
                               $args->{names});
    } elsif ($method eq 'et') {
        @result = rep_cent_tune($args->{basenote},
                               $args->{basefreq},
                               [0, 1200/$args->{nparam}],
                               $args->{names});
    } elsif ($method eq 'cents') {
        my @cents = split(/,/, $args->{nparam});
        @result = rep_cent_tune($args->{basenote},
                               $args->{basefreq},
                               \@cents,
                               $args->{names});
    } elsif ($method eq 'ratio') {
        my @ratios = split(/,/, $args->{nparam});
        my @cents;
        foreach (@ratios) {
            /^([0-9]+)\/([0-9]+)$/ && do {
                push @cents, log($1/$2)/log(2)*1200;
                };
            /^([0-9]+(\.[0-9+])?)$/ && do {
                push @cents, log($1)/log(2)*1200;
                };
        }
        @result = rep_cent_tune($args->{basenote},
                               $args->{basefreq},
                               \@cents,
                               $args->{names});
    }
    @freqs = @{$result[0]};
    @names = @{$result[1]} unless $#names>0;
}

my @regs = freq2reg(@freqs);
my @sgb_regs = freq2sgb(@freqs);
print_tuning(\@freqs, \@regs, \@names) unless $args->{quiet};

if (defined($args->{outfile})) {
    print "Writing tuned ROM to " . $args->{outfile} . "\n";
    copy($args->{rom}, $args->{outfile}) or die("Could not create output file!");
    open FOUT, '+<', $args->{outfile} or die("Could not open output file!");
    my ($tune_loc, $name_loc) = find_tables(FOUT);

    my $table = pack('S*', (@regs,@sgb_regs));
    seek FOUT, $tune_loc, SEEK_SET;
    print FOUT $table;

    if ($#names) {
        $table = '';
        foreach (@names) {
            $table .= pack("A3cX", $_);
        }
        $tab_offset = 0x1890;
        seek FOUT, $name_loc, SEEK_SET;
        print FOUT $table;
    }
    close FOUT;
}
