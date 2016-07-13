package Slic3r::Model;

use List::Util qw(first max any);
use Slic3r::Geometry qw(X Y Z move_points);

sub read_from_file {
    my $class = shift;
    my ($input_file) = @_;
    
    my $model = $input_file =~ /\.stl$/i            ? Slic3r::Format::STL->read_file($input_file)
              : $input_file =~ /\.obj$/i            ? Slic3r::Format::OBJ->read_file($input_file)
              : $input_file =~ /\.amf(\.xml)?$/i    ? Slic3r::Format::AMF->read_file($input_file)
              : die "Input file must have .stl, .obj or .amf(.xml) extension\n";
    
    die "The supplied file couldn't be read because it's empty.\n"
        if $model->objects_count == 0;
    
    $_->set_input_file($input_file) for @{$model->objects};
    return $model;
}

sub merge {
    my $class = shift;
    my @models = @_;
    
    my $new_model = ref($class)
        ? $class
        : $class->new;
    
    $new_model->add_object($_) for map @{$_->objects}, @models;
    return $new_model;
}

sub add_object {
    my $self = shift;
    
    if (@_ == 1) {
        # we have a Model::Object
        my ($object) = @_;
        return $self->_add_object_clone($object);
    } else {
        my (%args) = @_;
        
        my $new_object = $self->_add_object;
        
        $new_object->set_name($args{name})
            if defined $args{name};
        $new_object->set_input_file($args{input_file})
            if defined $args{input_file};
        $new_object->config->apply($args{config})
            if defined $args{config};
        $new_object->set_layer_height_ranges($args{layer_height_ranges})
            if defined $args{layer_height_ranges};
        $new_object->set_origin_translation($args{origin_translation})
            if defined $args{origin_translation};
        
        return $new_object;
    }
}

sub set_material {
    my $self = shift;
    my ($material_id, $attributes) = @_;
    
    my $material = $self->add_material($material_id);
    $material->apply($attributes // {});
    return $material;
}

sub looks_like_multipart_object {
    my ($self) = @_;
    
    return 0 if $self->objects_count == 1;
    return 0 if any { $_->volumes_count > 1 } @{$self->objects};
    return 0 if any { @{$_->config->get_keys} > 1 } @{$self->objects};
    
    my %heights = map { $_ => 1 } map $_->mesh->bounding_box->z_min, map @{$_->volumes}, @{$self->objects};
    return scalar(keys %heights) > 1;
}

sub convert_multipart_object {
    my ($self) = @_;
    
    my @objects = @{$self->objects};
    my $object = $self->add_object(
        input_file          => $objects[0]->input_file,
    );
    foreach my $v (map @{$_->volumes}, @objects) {
        my $volume = $object->add_volume($v);
        $volume->set_name($v->object->name);
    }
    $object->add_instance($_) for map @{$_->instances}, @objects;
    
    $self->delete_object($_) for reverse 0..($self->objects_count-2);
}

package Slic3r::Model::Material;

sub apply {
    my ($self, $attributes) = @_;
    $self->set_attribute($_, $attributes{$_}) for keys %$attributes;
}

package Slic3r::Model::Object;

use File::Basename qw(basename);
use List::Util qw(first sum);
use Slic3r::Geometry qw(X Y Z rad2deg);

sub add_volume {
    my $self = shift;

    my $new_volume;
    if (@_ == 1) {
        # we have a Model::Volume
        my ($volume) = @_;
        
        $new_volume = $self->_add_volume_clone($volume);
        
        if ($volume->material_id ne '') {
            #  merge material attributes and config (should we rename materials in case of duplicates?)
            if (my $material = $volume->object->model->get_material($volume->material_id)) {
                my %attributes = %{ $material->attributes };
                if ($self->model->has_material($volume->material_id)) {
                    %attributes = (%attributes, %{ $self->model->get_material($volume->material_id)->attributes })
                }
                my $new_material = $self->model->set_material($volume->material_id, {%attributes});
                $new_material->config->apply($material->config);
            }
        }
    } else {
        my %args = @_;
        
        $new_volume = $self->_add_volume($args{mesh});
        
        $new_volume->set_name($args{name})
            if defined $args{name};
        $new_volume->set_material_id($args{material_id})
            if defined $args{material_id};
        $new_volume->set_modifier($args{modifier})
            if defined $args{modifier};
        $new_volume->config->apply($args{config})
            if defined $args{config};
    }
    
    if ($new_volume->material_id ne '' && !defined $self->model->get_material($new_volume->material_id)) {
        # TODO: this should be a trigger on Volume::material_id
        $self->model->set_material($new_volume->material_id);
    }
    
    $self->invalidate_bounding_box;
    
    return $new_volume;
}

sub add_instance {
    my $self = shift;
    my %params = @_;
    
    if (@_ == 1) {
        # we have a Model::Instance
        my ($instance) = @_;
        return $self->_add_instance_clone($instance);
    } else {
        my (%args) = @_;
        
        my $new_instance = $self->_add_instance;
        
        $new_instance->set_rotation($args{rotation})
            if defined $args{rotation};
        $new_instance->set_scaling_factor($args{scaling_factor})
            if defined $args{scaling_factor};
        $new_instance->set_offset($args{offset})
            if defined $args{offset};
        
        return $new_instance;
    }
}

1;
