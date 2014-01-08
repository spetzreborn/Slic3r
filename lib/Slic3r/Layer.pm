package Slic3r::Layer;
use Moo;

use List::Util qw(first);
use Slic3r::Geometry qw(scale);
use Slic3r::Geometry::Clipper qw(union_ex);

has 'id'                => (is => 'rw', required => 1, trigger => 1); # sequential number of layer, 0-based
has 'object'            => (is => 'ro', weak_ref => 1, required => 1, handles => [qw(print config)]);
has 'upper_layer'       => (is => 'rw', weak_ref => 1);
has 'regions'           => (is => 'ro', default => sub { [] });
has 'slicing_errors'    => (is => 'rw');

has 'slice_z'           => (is => 'ro', required => 1); # Z used for slicing in unscaled coordinates
has 'print_z'           => (is => 'ro', required => 1); # Z used for printing in unscaled coordinates
has 'height'            => (is => 'ro', required => 1); # layer height in unscaled coordinates

# collection of expolygons generated by slicing the original geometry;
# also known as 'islands' (all regions and surface types are merged here)
has 'slices'            => (is => 'rw', default => sub { Slic3r::ExPolygon::Collection->new });

sub _trigger_id {
    my $self = shift;
    $_->_trigger_layer for @{$self->regions || []};
}

# the purpose of this method is to be overridden for ::Support layers
sub islands {
    my $self = shift;
    return $self->slices;
}

sub region {
    my $self = shift;
    my ($region_id) = @_;
    
    for (my $i = @{$self->regions}; $i <= $region_id; $i++) {
        $self->regions->[$i] //= Slic3r::Layer::Region->new(
            layer   => $self,
            region  => $self->object->print->regions->[$i],
        );
    }
    
    return $self->regions->[$region_id];
}

# merge all regions' slices to get islands
sub make_slices {
    my $self = shift;
    
    my $slices = union_ex([ map $_->p, map @{$_->slices}, @{$self->regions} ]);
    $self->slices->clear;
    $self->slices->append(@$slices);
}

sub make_perimeters {
    my $self = shift;
    Slic3r::debugf "Making perimeters for layer %d\n", $self->id;
    $_->make_perimeters for @{$self->regions};
}

package Slic3r::Layer::Support;
use Moo;
extends 'Slic3r::Layer';

# ordered collection of extrusion paths to fill surfaces for support material
has 'support_islands'           => (is => 'rw', default => sub { Slic3r::ExPolygon::Collection->new });
has 'support_fills'             => (is => 'rw', default => sub { Slic3r::ExtrusionPath::Collection->new });
has 'support_interface_fills'   => (is => 'rw', default => sub { Slic3r::ExtrusionPath::Collection->new });

sub islands {
    my $self = shift;
    return [ @{$self->slices}, @{$self->support_islands} ];
}

1;
