% Geometry with ESCDF

% Clear the workspace
clear; clc; close all;

% If you don't have ESCDF on your path, uncomment the following addpath 
% function and point it to the correct path

% addpath(genpath('/path/to/escdf'));

% Define the geometry of the cone
cone_angle = 10; % degrees
axial_stations = 0.1:0.3:2.2;
radial_stations = tan(cone_angle*pi/180)*axial_stations;
circumferential_stations = 0:30:330;

% Go through and construct the array of node positions.
% We will construct it so the nodes are in a 2D array of
% axial stations and circumferential stations
node_positions = zeros(3,length(circumferential_stations),length(axial_stations));
node_ids = zeros(length(circumferential_stations),length(axial_stations));
node_x_directions = zeros(3,length(circumferential_stations),length(axial_stations));
node_y_directions = zeros(3,length(circumferential_stations),length(axial_stations));
node_z_directions = zeros(3,length(circumferential_stations),length(axial_stations));
% Loop through axial and radial stations.  We will use enumerate
% to get the index as well as the values, and we will use zip
% to get one axial and one radial position with each loop.
for col_ind = 1:length(axial_stations)
    axial_position = axial_stations(col_ind);
    radial_position = radial_stations(col_ind);
    % Loop through circumferential stations, again using
    % enumerate to get the index as well as the value
    for row_ind = 1:length(circumferential_stations)
        circumferential_position = circumferential_stations(row_ind);
        % Add an entry to the last row we constructed
        node_positions(:,row_ind,col_ind) = [
            radial_position*cos(circumferential_position*pi/180), ...
            radial_position*sin(circumferential_position*pi/180), ...
            axial_position ...
            ];
        % There are 12 circumferential stations, so we need to
        % start the axial identifiers in the 100's place of the
        % identification number.
        node_ids(row_ind, col_ind) = 100*(col_ind) + row_ind;
        % Create the rotation matrices for the coordinate system.
        % This will be a compound rotation, first about the Y-axis
        % we rotate the negative cone angle, then about the Z-axis
        % we rotate the negative circumferential station angle
        s = sin(-cone_angle*pi/180);
        c = cos(-cone_angle*pi/180);
        R_y = [c, 0, s; ...
               0, 1, 0; ...
               -s, 0, c];
        s = sin(-circumferential_position*pi/180);
        c = cos(-circumferential_position*pi/180);
        R_z = [c, -s, 0; ...
               s, c, 0;  ...
               0, 0, 1];
        rot_mat = R_y * R_z;
        % The unit vectors for each local direction are the rows
        % of the rotation matrix
        node_x_directions(:,row_ind,col_ind) = rot_mat(1,:);
        node_y_directions(:,row_ind,col_ind) = rot_mat(2,:);
        node_z_directions(:,row_ind,col_ind) = rot_mat(3,:);
    end
end

% Transform into 2D arrays
node_ids = reshape(node_ids,[],1);
node_positions = reshape(node_positions,3,[]).';
node_x_directions = reshape(node_x_directions,3,[]).';
node_y_directions = reshape(node_y_directions,3,[]).';
node_z_directions = reshape(node_z_directions,3,[]).';

set(gcf, 'Units', 'inches', 'Position', [0, 0, 15, 10]);
for direction_index = 1:3
    if direction_index == 1
        direction = node_x_directions;
        color = 'r';
        label = 'Local X';
    elseif direction_index == 2
        direction = node_y_directions;
        color = 'g';
        label = 'Local Y';
    elseif direction_index == 3
        direction = node_z_directions;
        color = 'b';
        label = 'Local Z';
    end
    subplot(2,3,direction_index)
    x = node_positions(:,1);
    y = node_positions(:,3);
    plot(x,y,'ko');
    hold on;
    u = direction(:,1);
    v = direction(:,3);
    quiver(x,y,u,v,color);
    axis('equal');
    title(label)
    xlabel('Global x')
    ylabel('Global z')
    subplot(2,3,direction_index+3)
    x = node_positions(:,1);
    y = node_positions(:,2);
    plot(x,y,'ko');
    hold on;
    u = direction(:,1);
    v = direction(:,2);
    quiver(x,y,u,v,color);
    axis('equal');
    xlabel('Global x')
    ylabel('Global y')
end

% Create a translation motion
abscissa = linspace(0,10,201);
sine_signal = sin(2*pi*abscissa);
ordinates = [];
data_channels = {};
motion_direction = [0.2, -0.5, 0.3];

for node_index = 1:numel(node_ids)
    direction_labels = {'X-','Y-','Z+'};
    direction_vectors = {node_x_directions, node_y_directions, node_z_directions};

    for direction_index = 1:3
        direction_label = direction_labels{direction_index};
        direction_vector = direction_vectors{direction_index};

        data_channels{end+1,1} = sprintf('%d%s', node_ids(node_index), direction_label);

        if contains(direction_label, '-')
            polarity = -1;
        else
            polarity = 1;
        end

        coefficient = dot(direction_vector(node_index,:), motion_direction) * polarity;
        ordinates(end+1,:) = coefficient * sine_signal;
    end
end

figure;
plot(abscissa, ordinates.')
ylabel('Response')
xlabel('Time')

shape_matrix = [ ...
    -node_x_directions; ...
    -node_y_directions; ...
     node_z_directions];

shape_channels = {};
for d = {'X-','Y-','Z+'}
    for i = 1:numel(node_ids)
        shape_channels{end+1,1} = sprintf('%d%s', node_ids(i), d{1});
    end
end

frequencies = [0, 0, 0]; % Rigid body shapes have 0 Hz frequencies
dampings = [0, 0, 0];    % Rigid body shapes have undefined damping

disp(fileread('geometry.txt'))

es_geo = escdf_dataset( ...
    'cone_geometry', ...
    'geometry', ...
    'A Geometric Representation of a Cone with Local Coordinate Systems');

es_geo

es_geo.node_id = node_ids;
es_geo.node_position = node_positions;
es_geo.node_x_direction = node_x_directions;
es_geo.node_y_direction = node_y_directions;
es_geo.node_z_direction = node_z_directions;

es_geo.validate()

es_geo.position_units = {'m'};
es_geo.validate()

quad_stations = [1,2,3];
tri_stations = [4,5,6];
line_stations = [7,8];
circumferential_nodes = [1,2,3,4,5,6,7,8,9,10,11,12,1]; % Append 1 at the end

element_connectivity = {};
element_types = {};
element_colors = [];
line_connectivity = {};
line_colors = [];

for axial_index = 1:numel(axial_stations)
    axial_station = axial_index;

    for circumferential_index = 1:numel(circumferential_stations)
        node_1 = 100*(axial_station)   + circumferential_nodes(circumferential_index);
        node_2 = 100*(axial_station+1) + circumferential_nodes(circumferential_index);
        node_3 = 100*(axial_station+1) + circumferential_nodes(circumferential_index+1);
        node_4 = 100*(axial_station)   + circumferential_nodes(circumferential_index+1);

        if axial_station < 3
            % Quad element
            element_types{end+1,1} = 'quad4';
            element_connectivity{end+1,1} = uint64([node_1,node_2,node_3,node_4]);
            element_colors(end+1,:) = [0,0,255]; % R G B
        elseif axial_station < 6
            % Tri elements
            element_types{end+1,1} = 'tri3';
            element_connectivity{end+1,1} = uint64([node_1,node_2,node_3]);
            element_colors(end+1,:) = [255,0,0];

            element_types{end+1,1} = 'tri3';
            element_connectivity{end+1,1} = uint64([node_1,node_3,node_4]);
            element_colors(end+1,:) = [255,0,0];
        end
    end

    if axial_station >= 6
        line_connectivity{end+1,1} = uint64(100*(axial_station) + circumferential_nodes);
        line_colors(end+1,:) = [0,255,0]; % R G B
    end
end

es_geo.element_connection = element_connectivity;
es_geo.element_type = element_types;
es_geo.element_color = element_colors;
es_geo.line_connection = line_connectivity;
es_geo.line_color = line_colors;

disp(fileread('mode.txt'))

disp(fileread('data.txt'))

es_mode = escdf_dataset('rigid_modes','mode','Rigid shapes from a modal test.');

es_mode

% We transpose (.') frequencies and dampings
% to make them column 
es_mode.frequency = frequencies.';
es_mode.damping_ratio = dampings.';
es_mode.shape = shape_matrix;
es_mode.dof_name = shape_channels;

es_mode.validate()

es_data = escdf_dataset('rigid_motion','data','Motions from a rigid body check');

es_data

es_data.abscissa = abscissa.';
es_data.ordinate = ordinates;
es_data.abscissa_unit = {'s'};
es_data.ordinate_unit = {'m/s^2'};
% Need data_channels as an nx1 cell array/string array
es_data.channel = data_channels;
es_data.data_type = {'time response'};

es_data.validate()

es_file = escdf();
es_file.add_activity( ...
    'modal_test', ...
    'A modal test that acquired rigid body modes', ...
    datetime('now'));

es_file.add_data_to_activity('modal_test', es_data);
es_file.add_data_to_activity('modal_test', es_mode);

es_file.add_metadata(es_geo, 'modal_test');

es_file

es_file.write_to_disk('modal_test.esf', true);

es_file = escdf.load('modal_test.esf');

es_file

% Extract the relevant activity
activity_name = 'modal_test';
activity = es_file.activities.(activity_name);
activity_data = activity.data;

% Pull out all metadata attached to the activity, and only keep geometry types
all_metadata = es_file.get_activity_metadata(activity_name);
activity_geometries = {};
for i = 1:numel(all_metadata)
    if all_metadata(i).istype('geometry')
        activity_geometries{end+1} = all_metadata(i);
    end
end

% Check to make sure that we only got one geometry
if isempty(activity_geometries)
    error('No Geometry Found!')
elseif numel(activity_geometries) > 1
    error('Multiple Geometries Found!')
else
    activity_geometry = activity_geometries{1};
end

activity_geometry

es_mode = activity.get_data('rigid_modes');

% Extract relevant geometry information
node_ids = activity_geometry.node_id(:);
node_positions = activity_geometry.node_position(:);
node_x_directions = activity_geometry.node_x_direction(:);
node_y_directions = activity_geometry.node_y_direction(:);
node_z_directions = activity_geometry.node_z_direction(:);

% Create an empty array to populate with displacement data
node_displacements = zeros(numel(node_ids), 3);

shape_index = 1;
dof_index = 1;
shape_coefficient = es_mode.shape(dof_index, shape_index);

% This gives a cell array
dof_name = es_mode.dof_name(dof_index);
% The string name is the only item in this cell array
dof_name = dof_name{1}

if contains(dof_name, 'R')
    error("We can't handle Rotations yet!")
end
% Node number is everything except last two chars
node_id = str2double(dof_name(1:end-2));
% Second to last char is direction
direction_name = dof_name(end-1);
% Last char is polarity
if dof_name(end) == '-'
    polarity = -1;
else
    polarity = 1;
end
fprintf('Analyzing node %d in direction %s with polarity %d\n', node_id, direction_name, polarity);

node_index = find(node_id == node_ids);
fprintf('Node number %d is at index %d.\n', node_id, node_index(1));

if lower(direction_name) == 'x'
    direction = node_x_directions(node_index,:);
elseif lower(direction_name) == 'y'
    direction = node_y_directions(node_index,:);
elseif lower(direction_name) == 'z'
    direction = node_z_directions(node_index,:);
else
    error('Invalid Direction Name %s', direction_name)
end

displacement = polarity * shape_coefficient * direction;
fprintf('Degree of Freedom %s is moving [%g %g %g]\n', dof_name, displacement(1), displacement(2), displacement(3));

node_displacements(node_index,:) = node_displacements(node_index,:) + displacement;

% Create an empty array to populate with displacement data
node_displacements = zeros(numel(node_ids), 3);

for dof_index = 1:numel(es_mode.dof_name(:))
    dof_name = es_mode.dof_name(dof_index);
    dof_name = dof_name{1};
    shape_coefficient = es_mode.shape(dof_index, shape_index);

    if contains(dof_name, 'R')
        error("We can't handle Rotations yet!")
    end

    node_id = str2double(dof_name(1:end-2));
    direction_name = dof_name(end-1);

    if dof_name(end) == '-'
        polarity = -1;
    else
        polarity = 1;
    end

    fprintf('Analyzing node %d in direction %s with polarity %d\n', node_id, direction_name, polarity);

    node_index = find(node_id == node_ids);
    fprintf('  Node number %d is at index %d.\n', node_id, node_index(1));

    if lower(direction_name) == 'x'
        direction = node_x_directions(node_index,:);
    elseif lower(direction_name) == 'y'
        direction = node_y_directions(node_index,:);
    elseif lower(direction_name) == 'z'
        direction = node_z_directions(node_index,:);
    else
        error('  Invalid Direction Name %s', direction_name)
    end

    displacement = polarity * shape_coefficient * direction;
    fprintf('  Degree of Freedom %s is moving [%g %g %g]\n', dof_name, displacement(1), displacement(2), displacement(3));

    node_displacements(node_index,:) = node_displacements(node_index,:) + displacement;
end

node_displacements



[dof_names, global_displacements, global_rotations] = transform_shapes_to_global(es_mode, activity_geometry, true);

function varargout = transform_shapes_to_global(es_mode, es_geo, return_rotations, verbose)
    % Accepts a "mode" dataset and converts the shapes to global.
    %
    % Parameters
    % ----------
    % es_mode : escdf.Dataset
    %   ESCDF dataset with type "mode".
    % es_geo : escdf.Dataset
    %   ESCDF dataset with type "geometry".
    % return_rotations : logical
    %   If true, return rotation matrix as well.
    % verbose : logical
    %   If true, print debugging statements.
    %
    % Returns
    % -------
    % global_dof_names
    % global_shape_displacement_matrix
    % global_shape_rotation_matrix (optional)
    
    if nargin < 3
        return_rotations = false;
    end
    if nargin < 4
        verbose = false;
    end
    
    num_modes = size(es_mode.shape(:), 2);
    num_nodes = size(es_geo.node_id(:), 1);
    
    node_ids = es_geo.node_id(:);
    node_index_mapping = containers.Map('KeyType','double','ValueType','double');
    for i = 1:num_nodes
        node_index_mapping(node_ids(i)) = i;
    end
    
    global_shape_displacement_matrix = zeros(3, num_nodes, num_modes);
    if verbose
        fprintf('Created [%d %d %d] output array for displacements\n', size(global_shape_displacement_matrix));
    end
    
    if return_rotations
        global_shape_rotation_matrix = zeros(3, num_nodes, num_modes);
        if verbose
            fprintf('Created [%d %d %d] output array for rotations\n', size(global_shape_rotation_matrix));
        end
    end
    
    global_dof_names = cell(num_nodes*3,1);
    idx = 1;
    for i = 1:num_nodes
        for d = {'X+','Y+','Z+'}
            global_dof_names{idx} = sprintf('%d%s', node_ids(i), d{1});
            idx = idx + 1;
        end
    end
    
    if verbose
        disp('Created output degree of freedom names:')
        disp(global_dof_names)
    end
    
    name_pattern = '(\d+)([a-zA-Z]+)([+-])';
    
    for dof_index = 1:numel(es_mode.dof_name(:))
        dof_name = es_mode.dof_name(dof_index);
        dof_name = dof_name{1};
        shape_row = es_mode.shape(dof_index,:);
    
        name_match = regexp(dof_name, name_pattern, 'tokens', 'once');
        node_id = str2double(name_match{1});
        direction_str = name_match{2};
        polarity = str2double([name_match{3}, '1']);
    
        if contains(direction_str, 'R') && ~return_rotations
            if verbose
                fprintf('Skipping DoF %s because rotations not requested.\n', dof_name);
            end
            continue
        end
    
        if verbose
            fprintf('Analyzing DoF %s with node number %d, direction %s, and polarity %d\n', ...
                dof_name, node_id, direction_str, polarity);
        end
    
        node_index = node_index_mapping(node_id);
        if verbose
            fprintf('  Node %d is at index %d\n', node_id, node_index);
        end
    
        if contains(direction_str, 'X')
            direction = polarity * es_geo.node_x_direction(node_index,:);
        elseif contains(direction_str, 'Y')
            direction = polarity * es_geo.node_y_direction(node_index,:);
        elseif contains(direction_str, 'Z')
            direction = polarity * es_geo.node_z_direction(node_index,:);
        else
            error('Unknown Direction')
        end
    
        if verbose
            fprintf('  DoF %s is pointing [%g %g %g]\n', dof_name, direction(1), direction(2), direction(3));
        end
    
        dof_contributions = direction(:) * shape_row; % 3 x num_modes
    
        if verbose
            disp('  DoF contributions:')
            disp(dof_contributions)
        end
    
        if contains(direction_str, 'R')
            global_shape_rotation_matrix(:,node_index,:) = squeeze(global_shape_rotation_matrix(:,node_index,:)) + dof_contributions;
        else
            global_shape_displacement_matrix(:,node_index,:) = squeeze(global_shape_displacement_matrix(:,node_index,:)) + dof_contributions;
        end
    end
    
    global_shape_displacement_matrix = reshape(global_shape_displacement_matrix, [], num_modes);
    
    if return_rotations
        global_shape_rotation_matrix = reshape(global_shape_rotation_matrix, [], num_modes);
        varargout = {global_dof_names, global_shape_displacement_matrix, global_shape_rotation_matrix};
    else
        varargout = {global_dof_names, global_shape_displacement_matrix};
    end
end

mode_names = arrayfun(@(i) sprintf('Mode %d', i), 1:size(global_displacements,2), 'UniformOutput', false);

table_disp = array2table(global_displacements, 'VariableNames', mode_names, 'RowNames', dof_names);
table_rot  = array2table(global_rotations,    'VariableNames', mode_names, 'RowNames', dof_names);

table_disp

table_rot

es_data = activity.get_data('rigid_motion');

% Extract relevant geometry information
node_ids = activity_geometry.node_id(:);
node_positions = activity_geometry.node_position(:);
node_x_directions = activity_geometry.node_x_direction(:);
node_y_directions = activity_geometry.node_y_direction(:);
node_z_directions = activity_geometry.node_z_direction(:);

% Create an empty array to populate with displacement data
node_displacements = zeros(numel(node_ids), 3);

timestep_index = 2;
dof_index = 1;
local_disp = es_data.ordinate(dof_index, timestep_index);

dof_name = es_data.channel(dof_index,1);
dof_name = dof_name{1}

if contains(dof_name, 'R')
    error("We can't handle Rotations yet!")
end
node_id = str2double(dof_name(1:end-2));
direction_name = dof_name(end-1);

if dof_name(end) == '-'
    polarity = -1;
else
    polarity = 1;
end

fprintf('Analyzing node %d in direction %s with polarity %d\n', node_id, direction_name, polarity);

node_index = find(node_id == node_ids);
fprintf('Node number %d is at index %d.\n', node_id, node_index(1));

if lower(direction_name) == 'x'
    direction = node_x_directions(node_index,:);
elseif lower(direction_name) == 'y'
    direction = node_y_directions(node_index,:);
elseif lower(direction_name) == 'z'
    direction = node_z_directions(node_index,:);
else
    error('Invalid Direction Name %s', direction_name)
end

displacement = polarity * local_disp * direction;
fprintf('Degree of Freedom %s is moving [%g %g %g]\n', dof_name, displacement(1), displacement(2), displacement(3));

node_displacements(node_index,:) = node_displacements(node_index,:) + displacement;

% Create an empty array to populate with displacement data
node_displacements = zeros(numel(node_ids), 3);

for dof_index = 1:size(es_data.ordinate(:),1)
    dof_name = es_data.channel(dof_index,1);
    dof_name = dof_name{1};
    local_disp = es_data.ordinate(dof_index, timestep_index);

    if contains(dof_name, 'R')
        error("We can't handle Rotations yet!")
    end

    node_id = str2double(dof_name(1:end-2));
    direction_name = dof_name(end-1);

    if dof_name(end) == '-'
        polarity = -1;
    else
        polarity = 1;
    end

    fprintf('Analyzing node %d in direction %s with polarity %d\n', node_id, direction_name, polarity);

    node_index = find(node_id == node_ids);
    fprintf('  Node number %d is at index %d.\n', node_id, node_index(1));

    if lower(direction_name) == 'x'
        direction = node_x_directions(node_index,:);
    elseif lower(direction_name) == 'y'
        direction = node_y_directions(node_index,:);
    elseif lower(direction_name) == 'z'
        direction = node_z_directions(node_index,:);
    else
        error('  Invalid Direction Name %s', direction_name)
    end

    displacement = polarity * local_disp * direction;
    fprintf('  Degree of Freedom %s is moving [%g %g %g]\n', dof_name, displacement(1), displacement(2), displacement(3));

    node_displacements(node_index,:) = node_displacements(node_index,:) + displacement;
end

motion_direction

node_displacements ./ motion_direction



[dof_names, global_displacements, global_rotations] = transform_time_data_to_global(es_data, activity_geometry, true);

function varargout = transform_time_data_to_global(es_data, es_geo, return_rotations, verbose)
% Accepts a "data" dataset and converts the ordinate to global.
%
% Parameters
% ----------
% es_data : escdf.Dataset
%   ESCDF dataset with type "data" containing time response information.
% es_geo : escdf.Dataset
%   ESCDF dataset with type "geometry".
% return_rotations : logical
%   If true, return rotation matrix as well.
% verbose : logical
%   If true, print debugging statements.

    if nargin < 3
        return_rotations = false;
    end
    if nargin < 4
        verbose = false;
    end
    
    if ~strcmp(es_data.data_type(1), {'time response'})
        error('transform_time_data_to_global only works on "time response" data.')
    end
    
    num_timesteps = size(es_data.ordinate(:), 2);
    num_nodes = size(es_geo.node_id(:), 1);
    
    node_ids = es_geo.node_id(:);
    node_index_mapping = containers.Map('KeyType','double','ValueType','double');
    for i = 1:num_nodes
        node_index_mapping(node_ids(i)) = i;
    end
    
    global_displacement_matrix = zeros(3, num_nodes, num_timesteps);
    if verbose
        fprintf('Created [%d %d %d] output array for displacements\n', size(global_displacement_matrix));
    end
    
    if return_rotations
        global_rotation_matrix = zeros(3, num_nodes, num_timesteps);
        if verbose
            fprintf('Created [%d %d %d] output array for rotations\n', size(global_rotation_matrix));
        end
    end
    
    global_dof_names = cell(num_nodes*3,1);
    idx = 1;
    for i = 1:num_nodes
        for d = {'X+','Y+','Z+'}
            global_dof_names{idx} = sprintf('%d%s', node_ids(i), d{1});
            idx = idx + 1;
        end
    end
    
    if verbose
        disp('Created output degree of freedom names:')
        disp(global_dof_names)
    end
    
    name_pattern = '(\d+)([a-zA-Z]+)([+-])';
    
    for dof_index = 1:size(es_data.ordinate(:),1)
        dof_name = es_data.channel(dof_index,1);
        dof_name = dof_name{1};
        ordinate_row = es_data.ordinate(dof_index,:);
    
        name_match = regexp(dof_name, name_pattern, 'tokens', 'once');
        node_id = str2double(name_match{1});
        direction_str = name_match{2};
        polarity = str2double([name_match{3}, '1']);
    
        if contains(direction_str, 'R') && ~return_rotations
            if verbose
                fprintf('Skipping DoF %s because rotations not requested.\n', dof_name);
            end
            continue
        end
    
        if verbose
            fprintf('Analyzing DoF %s with node number %d, direction %s, and polarity %d\n', ...
                dof_name, node_id, direction_str, polarity);
        end
    
        node_index = node_index_mapping(node_id);
        if verbose
            fprintf('  Node %d is at index %d\n', node_id, node_index);
        end
    
        if contains(direction_str, 'X')
            direction = polarity * es_geo.node_x_direction(node_index,:);
        elseif contains(direction_str, 'Y')
            direction = polarity * es_geo.node_y_direction(node_index,:);
        elseif contains(direction_str, 'Z')
            direction = polarity * es_geo.node_z_direction(node_index,:);
        else
            error('Unknown Direction')
        end
    
        if verbose
            fprintf('  DoF %s is pointing [%g %g %g]\n', dof_name, direction(1), direction(2), direction(3));
        end
    
        dof_contributions = direction(:) * ordinate_row; % 3 x num_timesteps
    
        if verbose
            disp('  DoF contributions:')
            disp(dof_contributions)
        end
    
        if contains(direction_str, 'R')
            global_rotation_matrix(:,node_index,:) = squeeze(global_rotation_matrix(:,node_index,:)) + dof_contributions;
        else
            global_displacement_matrix(:,node_index,:) = squeeze(global_displacement_matrix(:,node_index,:)) + dof_contributions;
        end
    end
    
    global_displacement_matrix = reshape(global_displacement_matrix, [], num_timesteps);
    
    if return_rotations
        global_rotation_matrix = reshape(global_rotation_matrix, [], num_timesteps);
        varargout = {global_dof_names, global_displacement_matrix, global_rotation_matrix};
    else
        varargout = {global_dof_names, global_displacement_matrix};
    end
end

time_names = arrayfun(@(t) sprintf('t=%0.2fs', t), es_data.abscissa(:), 'UniformOutput', false);

table_disp = array2table(global_displacements, 'VariableNames', time_names, 'RowNames', dof_names);
table_rot  = array2table(global_rotations,    'VariableNames', time_names, 'RowNames', dof_names);

table_disp(:,1:10)

table_rot(:,1:10)
