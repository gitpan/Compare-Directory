package Compare::Directory;

use warnings; use strict;

=head1 NAME

Compare::Directory - A very simple utility to compare directory.

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';

use Carp;
use CAM::PDF;
use Test::Excel;
use Test::Deep ();
use Data::Dumper;
use File::Compare;
use File::Basename;
use XML::SemanticDiff;
use Scalar::Util 'blessed';
use File::Spec::Functions;
use File::Glob qw(bsd_glob);

=head1 SYNOPSIS

The one and only objective of this module is compare two directory contents.
Currently it can only compare the following file types:

=over 5

=item .txt: Text File

=item .csv: Comma Seperated File

=item .pdf: PDF File

=item .xml: XML File

=item .xls: Excel File

=back

=head1 CONSTRUCTOR

The constructor expects the two directories name with complete path.

   use strict; use warnings;
   use Compare::Directory;
   
   my $directory = Compare::Directory("./got-1", "./exp-1");
   
=cut

sub new
{
    my $class = shift;
    my $dir1  = shift;
    my $dir2  = shift;
    croak("ERROR: Please provide two directories to compare.\n")
        unless (defined($dir1) && defined($dir2));
    croak("ERROR: Invalid directory [$dir1].\n") unless (-d $dir1);
    croak("ERROR: Invalid directory [$dir2].\n") unless (-d $dir2);

    # Borrowed from DirCompare [http://search.cpan.org/~gavinc/File-DirCompare-0.6/DirCompare.pm]
    my $self = {};
    $self->{name1} = $dir1;
    $self->{name2} = $dir2;
    $self->{dir1}->{basename $_} = 1 foreach bsd_glob(catfile($dir1, ".*"));
    $self->{dir1}->{basename $_} = 1 foreach bsd_glob(catfile($dir1, "*"));
    $self->{dir2}->{basename $_} = 1 foreach bsd_glob(catfile($dir2, ".*"));
    $self->{dir2}->{basename $_} = 1 foreach bsd_glob(catfile($dir2, "*"));

    delete $self->{dir1}->{curdir()} if $self->{dir1}->{curdir()};
    delete $self->{dir1}->{updir()}  if $self->{dir1}->{updir()};
    delete $self->{dir2}->{curdir()} if $self->{dir2}->{curdir()};
    delete $self->{dir2}->{updir()}  if $self->{dir2}->{updir()};
    
    $self->{_status} = 1;
    map { $self->{entry}->{$_}++ == 0 ? $_ : () } sort(keys(%{$self->{dir1}}), keys(%{$self->{dir2}}));
    $self->{report} = sub 
    {
        my ($a, $b) = @_;
        if (!$b) 
        {
            printf("Only in [%s]: [%s].\n", dirname($a), basename($a));
            $self->{_status} = 0;
        } elsif (!$a) 
        {
            printf("Only in [%s]: [%s].\n", dirname($b), basename($b));
            $self->{_status} = 0;
        } 
        else 
        {
            printf("Files [%s] and [%s] differ.\n", $a, $b);
            $self->{_status} = 0;
        }
    };
    
    bless $self, $class;
    return $self;
}    
    
=head1 METHODS

=head2 cmp_directory()

This is the public that initiates the actual directory comparison. You simply call 
this method against the object. Returns 1 if directory comparison succeed otherwise
returns 0.

   use strict; use warnings;
   use Compare::Directory;
   
   my $directory = Compare::Directory("./got-1", "./exp-1");
   $directory->cmp_directory();
   
=cut

sub cmp_directory
{
    my $self = shift;
    foreach my $entry (keys %{$self->{entry}})
    {
        my $f1 = catfile($self->{name1}, $entry);
        my $f2 = catfile($self->{name2}, $entry);
        next if (-d $f1 && -d $f2);
    
        if (!$self->{dir1}->{$entry}) 
        {
            $self->{report}->($f1, undef);
        } 
        elsif (!$self->{dir2}->{$entry}) 
        {
            $self->{report}->(undef, $f2);
        }
        else
        {
            $self->{report}->($f1, $f2) unless _cmp_directory($f1, $f2);
            # Very strict about the order of elements in XML.
            # $self->{report}->($f1, $f2) if File::Compare::compare($f1, $f2);
        }
    }
    return $self->{_status};
}

=head2 _cmp_directory($$)

This is an internal method where the actual comparison happens. This gets called
by the method cmp_directory().

=cut

sub _cmp_directory($$)
{
    my $file1 = shift;
    my $file2 = shift;
    croak("ERROR: Invalid file [$file1].\n") unless(defined($file1) && (-f $file1));
    croak("ERROR: Invalid file [$file2].\n") unless(defined($file2) && (-f $file2));
    
    my $do_FILEs_match = 0;
    if ($file1 =~ /\.txt|\.csv/i)
    {
        $do_FILEs_match = 1 unless compare($file1, $file2);
    }
    elsif ($file1 =~ /\.xml/i)
    {
        my $diff = XML::SemanticDiff->new();
        $do_FILEs_match = 1 unless $diff->compare($file1, $file2);
    }
    elsif ($file1 =~ /\.pdf/i)
    {
        $do_FILEs_match = 1 if _cmp_pdf($file1, $file2);
    }
    elsif ($file1 =~ /\.xls/i)
    {
        $do_FILEs_match = 1 if compare_excel($file1, $file2);
    }
    return $do_FILEs_match;
}

=head2 _cmp_pdf()

This is an internal method for PDF comparison. Code borrowed from Test::PDF.
[http://search.cpan.org/~stevan/Test-PDF-0.01/lib/Test/PDF.pm]

=cut

sub _cmp_pdf($$) 
{
    my $got = shift;
    my $exp = shift;
    
    unless (blessed($got) && $got->isa('CAM::PDF')) 
    {
        $got = CAM::PDF->new($got) 
            || croak("ERROR: Couldn't create CAM::PDF instance with: [$got]\n");
    }
    unless (blessed($exp) && $exp->isa('CAM::PDF')) 
    {
        $exp = CAM::PDF->new($exp) 
            || croak("ERROR: Couldn't create CAM::PDF instance with: [$exp]\n");
    }    
    
    return 0 unless ($got->numPages() == $exp->numPages());

    my $do_PDFs_match = 0;
    foreach my $page_num (1 .. $got->numPages()) 
    {
        my $tree1 = $got->getPageContentTree($page_num, "verbose");
        my $tree2 = $exp->getPageContentTree($page_num, "verbose");
        if (Test::Deep::eq_deeply($tree1->{blocks}, $tree2->{blocks})) 
        {
            $do_PDFs_match = 1;
        }
        else 
        {
            $do_PDFs_match = 0;            
            last;
        }
    }
    return $do_PDFs_match; 
}

=head1 AUTHOR

Mohammad S Anwar, E<lt>mohammad.anwar@yahoo.comE<gt>

=head1 BUGS

Please report any bugs or feature requests to C<bug-compare-directory at rt.cpan.org>, 
or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Compare-Directory>.  
I will be notified, and then you'll automatically be notified of progress on your bug 
as I make changes.

=head1 SEE ALSO

=over 2

=item File::DirCompare

=item File::Dircmp_directory

=back

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Compare::Directory

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Compare-Directory>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Compare-Directory>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Compare-Directory>

=item * Search CPAN

L<http://search.cpan.org/dist/Compare-Directory/>

=back

=head1 ACKNOWLEDGEMENTS

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Mohammad S Anwar.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1; # End of Compare::Directory