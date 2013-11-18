#!/usr/bin/perl

use XML::FeedPP;
use Data::Dumper;
use XML::Simple;
use LWP::UserAgent;
use Date::Manip;

# Change to the public_html/genconnect directory
#chdir ("/home/rviana/public_html/genconnect");

my $google_URL = "http://gdata.youtube.com/feeds/api/videos/";
my $yerp_URL = "http://mini.yerp.com/~rviana/genconnect/";

my $infile = shift @ARGV;
my $hashref = parse_file($infile);
my %hash = %{$hashref};
$hashref = parse_hash(\%hash);

#debug ($hashref);

my $feed_string = make_feed($hashref);
print $feed_string , "\n";

sub make_feed {
	my $hashref = shift @_;
	my %hash = %{$hashref};
	my $feed = XML::FeedPP::RSS->new();
	$feed->xmlns('xmlns:media' => 'http://search.yahoo.com/mrss/');

	$feed->title ("Genconnect MRSS Feed");
	$feed->description ("Genconnect MRSS Feed Description");
	$feed->link ("http://www.genconnect.com/");
	$feed->pubDate (UnixDate("now", "%g"));

	foreach my $key (keys %hash) {
		my $item = $feed->add_item($hash{$key}{url});
		$item->guid($key, isPermaLink=>"false" );
		$item->set('description' => $hash{$key}{"media:description"} );
		$item->set('title' => $hash{$key}{"media:title"} );
		$item->set('pubDate' => $hash{$key}{"published"} );
		$item->set('media:title' => $hash{$key}{"media:title"} );
		$item->set('media:description' => $hash{$key}{"media:description"} );
		$item->set('media:description@type' => "html" );
		$item->set('media:content@url' => $hash{$key}{url});
		$item->set('media:content@type' => $hash{$key}{"media:content"}{type});
		$item->set('media:content@duration' => $hash{$key}{"media:content"}{duration});
		$item->set('media:thumbnail@url' => $hash{$key}{"media:thumbnail"}{url});
		$item->set('media:thumbnail@width' => $hash{$key}{"media:thumbnail"}{width});
		$item->set('media:thumbnail@height' => $hash{$key}{"media:thumbnail"}{height});
		$item->set('media:thumbnail@time' => $hash{$key}{"media:thumbnail"}{time});
		$item->set('media:category' => $hash{$key}{"aol_category"});
		$item->set('media:keywords' => $hash{$key}{"keywords"});
	}

	$string = $feed->to_string( indent => 4 );
	return $string;
}

sub parse_hash {
	my $hashref = shift @_;
	my %hash = %{$hashref};
	foreach my $key (keys %hash) {
		my $xml = get_meta($key);
		my $data = XMLin($xml);
		#print Dumper $data;
		$hash{$key}{"media:description"} = $data->{"media:group"}->{"media:description"}->{content} ;
		$hash{$key}{"media:title"} = $data->{"media:group"}->{"media:title"}->{content} ;
		$hash{$key}{"media:content url"} = $data->{"media:group"}->{"media:player"}->{url};
		$hash{$key}{"media:thumbnail"}{url} = $data->{"media:group"}->{"media:thumbnail"}->[0]->{url};
		$hash{$key}{"media:thumbnail"}{height} = $data->{"media:group"}->{"media:thumbnail"}->[0]->{height};
		$hash{$key}{"media:thumbnail"}{width} = $data->{"media:group"}->{"media:thumbnail"}->[0]->{width};
		$hash{$key}{"media:thumbnail"}{time} = $data->{"media:group"}->{"media:thumbnail"}->[0]->{time};
		$hash{$key}{"media:content"}{duration} = $data->{"media:group"}->{"media:content"}->[0]->{duration};
		$hash{$key}{"media:content"}{type} = $data->{"media:group"}->{"media:content"}->[0]->{type};
		$hash{$key}{"media:content"}{type} = "video/mp4";  #Hack for my vids
		$hash{$key}{"media:content"}{url} = $data->{"media:group"}->{"media:content"}->[0]->{url};
		$hash{$key}{"media:category"} = $data->{"media:group"}->{"media:category"}->{content};
		$hash{$key}{"media:keywords"} = $data->{"media:group"}->{"media:keywords"};

		my $date = UnixDate( $data->{"published"}, "%g" );
		$hash{$key}{"published"} = $date;

#last;
	}
	return \%hash;
}

sub debug {
	my $hashref = shift @_;
	my %hash = %{$hashref};
	foreach my $youtube_id (keys %hash) {
		print "$youtube_id: { ";
		foreach my $tag (keys %{ $hash{$youtube_id} } ) {
			if ( ref($hash{$youtube_id}{$tag}) eq "HASH") {
				foreach my $subtag (keys %{ $hash{$youtube_id}{$tag} }) {
					print "\t\t$tag=$subtag=$hash{$youtube_id}{$tag}{$subtag}\n";
				}
			}
			else {
				print "\t$tag=$hash{$youtube_id}{$tag} \n ";
			}
		}
		print "}\n";
	}
}

sub get_meta {
	my $youtube_id = shift @_;
	my $source = $google_URL . $youtube_id . "?v=2";
	my $ua = LWP::UserAgent->new;
# X-GData-Key: key=<developer_key>
	$ua->default_header('X-GData-Key' => "key=AI39si4-LwPAWh9a3zhPMHLNhaBNDz1gJOYhRxYKJUXxcuPMFoqYFWP5-uMToi1ciiNdw9FbvtgcpBNAcEzTHzi5T5CuUEcOKw");
	$ua->agent($0);
	my $response = $ua->get($source);
	if ($response->is_success) {
#print $response->decoded_content;  # or whatever
#print $response->as_string;
		return $response->decoded_content;
	}
	else {
		die $response->status_line;
	} 
}


sub parse_file {
	my $infile = shift @_;
	my %hash;
	open (INFILE, $infile);
	while (<INFILE>){
		chomp;
		if ( /^([^;]+);([^;]+);([^;]+);([^;]+)/) {
			my ($youtube_id, $keywords, $category, $url) = ($1, $2, $3, $4);
#print "Youtube ID: $youtube_id \n";
			$hash{$youtube_id}{"aol_category"} = $category;
			$hash{$youtube_id}{"keywords"} = $keywords;
			$hash{$youtube_id}{"url"} = $yerp_URL . $url;
		} else { next;}
	}
	return \%hash;
}


sub create_feed {
	my $feed = XML::FeedPP::RSS->new();
	$feed->xmlns('xmlns:media' => 'http://search.yahoo.com/mrss/');
	my $item = $feed->add_item('http://www.example.com/index.html');
	$item->set('media:content@url' => 'http://www.example.com/image.jpg');
	$item->set('media:content@type' => 'image/jpeg');
	$item->set('media:content@width' => 640);
	$item->set('media:content@height' => 480);

##print $feed->to_string(); ;
}
