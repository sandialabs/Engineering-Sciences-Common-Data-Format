% Reading Eigensolution Results from ESCDF to Exodus
% Example problem created by Dan Rohe, 1522

% Clear the workspace
clear; clc; close all;

% If you don't have exodus tools or ESCDF on your path,
% uncomment the following addpath functions and point
% them to the correct paths.

% addpath(genpath('/path/to/MatlabExodusUtilities1553'));
% addpath(genpath('/path/to/escdf'));

% Load in the Modal Results Data

% To show interoperability, we will load in the ESCDF file created by
% Python in this file.
esfile = escdf.load('framewing_eigen_escdf_py.esf');

esfile

% Identify the modal data we are after

% We will identify the activity containing the modal data
esact = esfile.activities(1);

esact

% A general ESCDF file may have multiple geometries and other metadata,
% so best practice is to use links between the activity and metadata
% to find the relevant geometry
metadata_links = esact.get_metadata_links();
% Find the metadata that is a geometry
esgeo = [];
for i = 1:length(metadata_links)
    metadata = esfile.metadata.(metadata_links{i});
    if metadata.istype('geometry')
        esgeo = metadata;
    end
end
if isempty(esgeo)
    error(['No geometry found linked to activity ',esactivity.get_name()])
end

% Get the data in a similar way
esmode = [];
esdata = esact.get_data();
for i = 1:length(esdata)
    data = esdata(i);
    if data.istype('mode')
        esmode = data;
    end
end
if isempty(esmode)
    error(['No mode data found in activity ',esactivity.get_name()])
end

esgeo

% Extract the geometry information

% Exodus needs node and element information to set up the exodus file.
% Let's extract that information
node_ids = esgeo.node_id(:);
coords = esgeo.node_position(:);

% We should also extract the local coordinate system information.
% Note that this particular file has everything in global coordinates,
% however, a general modal data package from an experimental group
% might not.  Therefore we should get used to understanding how to
% work with local coordinate system directions
node_x_dir = esgeo.node_x_direction(:);
node_y_dir = esgeo.node_y_direction(:);
node_z_dir = esgeo.node_z_direction(:);

% Finally, let's extract the element information.  We've lost all
% all references to the original element blocks.  Also, a general
% modal package from an experimental group would never have had
% blocks to begin with, so we should go through and create new
% blocks based on element types anyway
all_element_types = esgeo.element_type(:);
all_element_connectivities = esgeo.element_connection(:);

element_types = unique(all_element_types);

% We need to map the element types in ESCDF to the element types in
% Exodus
elem_map = containers.Map({'sphere1','bar2','hex20'},{'SPHERE','BEAM','HEX20'});
% We also need to map the node numbers back to the indices to use with
% Exodus
node_map_inv = containers.Map(node_ids,1:length(node_ids));

% Loop through each block type to extract the connectivity matrix
block_connectivities = {};
for i = 1:length(element_types)
    block_indices = strcmp(all_element_types,element_types{i});
    block_connectivity = [all_element_connectivities{block_indices,:}].';
    % Apply the inverse node map.  It seems that maps only accept one item
    % at a time, so we need to use arrayfun to map each item.
    block_connectivities{end+1} = arrayfun(@(item) node_map_inv(item),...
        block_connectivity);
end

% We should also map our element types, this time again using cellfun
exodus_block_types = cellfun(@(item) elem_map(item), element_types, ...
    'UniformOutput',false);

esmode

% Extract Modal Information

% With the geometry extracted, we can now pull the modal data from the
% file.  In general, the mode shape information cannot be assumed to be
% in the same order as the node id numbers in the geometry, so we will have
% to use the dof_name property to help us sort the data.  Additionally,
% we will use the local node directions to help us convert the data to
% the global displacements desired by the exodus file.

frequencies = esmode.frequency(:);
shape_array = esmode.shape(:);
dof_names = esmode.dof_name(:);

% Initialize an array of zeros
displacement_shapes = zeros(length(node_ids),3,length(frequencies));
rotation_shapes = zeros(length(node_ids),3,length(frequencies));

% Go through each degree of freedom in the shape list and add it to the
% correct index
name_pattern = '(\d+)([a-zA-Z]+)([+-])';
name_parts = regexp(dof_names,name_pattern,'tokens');
for i = 1:length(dof_names)
    % Extract the parts of the dof name
    node_num = str2double(name_parts{i}{1}{1});
    direction_str = name_parts{i}{1}{2};
    polarity = str2double([name_parts{i}{1}{3},'1']);
    % Get the node index from the node map
    node_index = node_map_inv(node_num);
    % Use the direction string to select the correct direction vector
    if contains(direction_str,'X')
        direction = polarity*node_x_dir(node_index,:);
    elseif contains(direction_str,'Y')
        direction = polarity*node_y_dir(node_index,:);
    elseif contains(direction_str,'Z')
        direction = polarity*node_z_dir(node_index,:);
    else
        error('Unknown Direction')
    end
    shape_coefficients = shape_array(i,:);
    % Multiply the shape coefficients by the direction vector (using
    % broadcasting) and add to the correct matrix.  We add because there is
    % a contribution from X, Y, and Z local directions.
    if contains(direction_str,'R')
        rotation_shapes(node_index,:,:) = squeeze(rotation_shapes(node_index,:,:)) + direction.'*shape_coefficients;
    else
        displacement_shapes(node_index,:,:) = squeeze(displacement_shapes(node_index,:,:)) + direction.'*shape_coefficients;
    end
end

% Build the exodus file

% Now we need to package the extracted data into the Exodus format.
% We will begin by creating an empty file
exo = FEMesh.Exodus();
% Add geometry information
exo.Nodes = FEMesh.Nodes(coords,node_ids,{'x','y','z'});
exo.Blocks = FEMesh.Blocks(1:length(exodus_block_types));
[exo.Blocks.ElementType] = exodus_block_types{:};
[exo.Blocks.Connectivity] = block_connectivities{:};
[exo.Blocks.Name] = exodus_block_types{:};
% Add modal information
exo.Time = frequencies;
exo.NodalVars = FEMesh.NodalVars({'DispX','DispY','DispZ','RotX','RotY','RotZ'});
exo.NodalVars(1).Data = squeeze(displacement_shapes(:,1,:));
exo.NodalVars(2).Data = squeeze(displacement_shapes(:,2,:));
exo.NodalVars(3).Data = squeeze(displacement_shapes(:,3,:));
exo.NodalVars(4).Data = squeeze(rotation_shapes(:,1,:));
exo.NodalVars(5).Data = squeeze(rotation_shapes(:,2,:));
exo.NodalVars(6).Data = squeeze(rotation_shapes(:,3,:));
% Make everything else empty
exo.Nodesets=FEMesh.Nodesets([]);
exo.Sidesets=FEMesh.Sidesets([]);
exo.GlobalVars=FEMesh.GlobalVars([]);
exo.ElemVars=FEMesh.ElemVars(1,[]);
exo.NodesetVars=FEMesh.NodesetVars([]);
exo.SidesetVars=FEMesh.SidesetVars([]);

% Query the Exodus File
exo

% Write the data to disk
exo_put('framewing_eigen_from_escdf_mat.exo',exo);
