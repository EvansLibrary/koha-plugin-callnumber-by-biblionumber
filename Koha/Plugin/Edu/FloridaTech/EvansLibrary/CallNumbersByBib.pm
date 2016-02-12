package Koha::Plugin::Edu::FloridaTech::EvansLibrary::CallNumbersByBib;

## It's good practive to use Modern::Perl
use Modern::Perl;

## Required for all plugins
use base qw(Koha::Plugins::Base);

## We will also need to include any Koha libraries we want to access
use C4::Context;
use C4::Branch;
use C4::Members;
use C4::Auth;
use Koha::Database;

## Here we set our plugin version
our $VERSION = 1.00;

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name            => 'Call Numbers by Biblionumber',
    author          => 'Thomas J Misilo',
    description     => 'Call Numbers by Biblionumber.',
    date_authored   => '2016-02-01',
    date_updated    => '2016-02-01',
    minimum_version => '3.18',
    maximum_version => undef,
    version         => $VERSION,
};

## This is the minimum code required for a plugin's 'new' method
## More can be added, but none should be removed
sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    return $self;
}

## The existance of a 'report' subroutine means the plugin is capable
## of running a report. This example report can output a list of patrons
## either as HTML or as a CSV file. Technically, you could put all your code
## in the report method, but that would be a really poor way to write code
## for all but the simplest reports
sub report {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('output') ) {
        $self->report_step1();
    }
    else {
        $self->report_step2();
    }
}

## These are helper functions that are specific to this plugin
## You can manage the control flow of your plugin any
## way you wish, but I find this is a good approach
sub report_step1 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $template = $self->get_template( { file => 'report-step1.tt' } );

    $template->param(
        branches_loop   => GetBranchesLoop(),
        categories_loop => GetBorrowercategoryList(),
    );

    print $cgi->header();
    print $template->output();
}

sub report_step2 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $dbh = C4::Context->dbh;

    my $barcodes = $cgi->param('barcodes');
    my $output        = $cgi->param('output');

    my @barcodes = split( /[\n,\r\n,\t,\,]/, $barcodes );
    map { $_ =~ s/^\s+|\s+$//g  } @barcodes;

    my $query ="
    select
        bib.biblionumber,
        bib.title,
        group_concat(i.itemnumber, ',' , i.itemcallnumber SEPARATOR '|' ) as 'itemnumbercallnumber'
    from
        biblio bib
    inner join items i using (biblionumber)
    WHERE bib.biblionumber IN (" . join( ',', map {'?'} @barcodes ) . ")
    group by biblionumber";
   
    my $sth = $dbh->prepare($query);

    $sth->execute(@barcodes); 

    my @items;
    while ( my $row = $sth->fetchrow_hashref() ) {
        push( @items, $row );
    }

    my $filename;
    if ( $output eq "csv" ) {
        print $cgi->header( -attachment => 'records.csv' );
        $filename = 'report-step2-csv.tt';
    }
    else {
        print $cgi->header();
        $filename = 'report-step2-html.tt';
    }

    my $template = $self->get_template( { file => $filename } );

    $template->param( items => \@items );

    print $template->output();
}

1;
