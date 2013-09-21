use Test::More tests => 1;
use strict;
use warnings;

BEGIN {
    use FindBin;
    use lib "$FindBin::Bin/../lib";
}

use List::Util qw(first);
use Math::ConvexHull::MonotoneChain qw(convex_hull);
use Slic3r;
use Slic3r::Test;

{
    my $config = Slic3r::Config->new_from_defaults;
    $config->set('infill_extruder', 2);
    $config->set('standby_temperature', 1);
    $config->set('temperature', [200, 180]);
    $config->set('first_layer_temperature', [206, 186]);
    
    my $print = Slic3r::Test::init_print('20mm_cube', config => $config);
    
    my $tool = undef;
    my @tool_temp = (0,0);
    my @toolchange_points = ();
    my @extrusion_points = ();
    Slic3r::GCode::Reader->new->parse(Slic3r::Test::gcode($print), sub {
        my ($self, $cmd, $args, $info) = @_;
        
        if ($cmd =~ /^T(\d+)/) {
            if (defined $tool) {
                my $expected_temp = $self->Z == ($config->get_value('first_layer_height') + $config->z_offset)
                    ? $config->first_layer_temperature->[$tool]
                    : $config->temperature->[$tool];
                die 'standby temperature was not set before toolchange'
                    if $tool_temp[$tool] != $expected_temp + $config->standby_temperature_delta;
            }
            $tool = $1;
            push @toolchange_points, Slic3r::Point->new_scale($self->X, $self->Y);
        } elsif ($cmd eq 'M104' || $cmd eq 'M109') {
            my $t = $args->{T} // $tool;
            if ($tool_temp[$t] == 0) {
                fail 'initial temperature is not equal to first layer temperature + standby delta'
                    unless $args->{S} == $config->first_layer_temperature->[$t] + $config->standby_temperature_delta;
            }
            $tool_temp[$t] = $args->{S};
        } elsif ($cmd eq 'G1' && $info->{extruding} && $info->{dist_XY} > 0) {
            push @extrusion_points, Slic3r::Point->new_scale($args->{X}, $args->{Y});
        }
        # TODO: check that toolchanges retraction and restart happen outside skirt
    });
    my $convex_hull = Slic3r::Polygon->new(@{convex_hull([ map $_->pp, @extrusion_points ])});
    ok !(first { $convex_hull->encloses_point($_) } @toolchange_points), 'all toolchanges happen outside skirt';
}

__END__
