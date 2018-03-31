#!/usr/bin/perl -w

package ConnSetting; {
  use strict;
  use JSON;
  
  my $propertiesFileName;
  
  sub new {
    my($class, $confFileName) = @_;
    $propertiesFileName = $confFileName;
    my %props = loadPropsFromFile();
    my $self  = {
      props => \%props,
    };                      
    bless $self, $class;    
    return $self;
  }
  
  sub getProps {
    my($args) = @_;
    return $args->{props};
  }
  
  sub savePropsToFile {
    my($args) = @_;
    my %props = %{$args->{props}};
    my $jsonString = encode_json \%props;
    open(FILE, '>', $propertiesFileName);
    print FILE $jsonString;
    close FILE;
  }
  
  sub loadPropsFromFile {
    open FILE, $propertiesFileName or die "Failed to open file";
    my @lines = <FILE>;
    close FILE;
    my $res = decode_json(join(" ", @lines));
    return %$res;
  }
}

1;
