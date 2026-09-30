%% Writing Sierra/SD Eigensolution Results to ESCDF
% Example problem created by Dan Rohe, 1522

% Clear the workspace
clear; clc; close all;

% If you don't have exodus tools or ESCDF on your path,
% uncomment the following addpath functions and point
% them to the correct paths.

% addpath(genpath('/path/to/MatlabExodusUtilities1553'));
% addpath(genpath('/path/to/escdf'));

%% Load in the Finite Element Results
% Here we will load in the finite element results exodus file.

exo = exo_rd('frame_wing_thick_v2_si-eig.exo');

exo

%% Create an Empty ESCDF File that we will populate

esfile = escdf();

esfile

% Create an empty Geometry dataset

esgeo = escdf_dataset('mesh_geometry','geometry',...
    'Mesh for frame_wing_thick_v2_si-eig.exo');

esgeo

% Populate the Geometry dataset

% First let's extract the node identification numbers, which we will put
% into the node_id field.
node_ids = int64(exo.Nodes.NodeNumMap);
esgeo.node_id = node_ids;

% Now let's extract the coordinates of the nodes, which we will put into the
% node_position field.
coordinates = exo.Nodes.Coordinates;
esgeo.node_position = coordinates;

esgeo

% Populate the Element Properties

% See what types of elements exist in the model
exo.Blocks

elem_map = containers.Map({'SPHERE','BEAM','HEX20'},{'sphere1','bar2','hex20'});

% Initialize empty cell arrays
element_connectivity = {};
element_types = {};

% Loop through each element in each block and get the connectivity
% and the element type
for block_index = 1:length(exo.Blocks)
    block = exo.Blocks(block_index);
    % Make sure we map connectivity to node number, not index
    connectivity = node_ids(block.Connectivity);
    % Use elem_map to transform exodus type into ESCDF type
    mapped_type = elem_map(block.ElementType);
    for element_index = 1:size(connectivity,1)
        element_connectivity{end+1} = connectivity(element_index,:);
        element_types{end+1} = mapped_type;
    end
end

% Add the items to the geometry object, note the transposes .'
esgeo.element_connection = element_connectivity.';
esgeo.element_type = element_types.';

esgeo

esgeo.validate()

% We can easily use repmat to generate the correctly sized node direction
% properties
node_x_dir = repmat([1,0,0],length(node_ids),1);
node_y_dir = repmat([0,1,0],length(node_ids),1);
node_z_dir = repmat([0,0,1],length(node_ids),1);

esgeo.node_x_direction = node_x_dir;
esgeo.node_y_direction = node_y_dir;
esgeo.node_z_direction = node_z_dir;

% The units of our model are in meters
esgeo.position_units = {'m'};

esgeo

esgeo.validate()

% Populate Eigensolution Data

esmode = escdf_dataset('eigen','mode',...
    'Sierra/SD Eigensolution from frame_wing_thick_v2_si-eig.exo');

esmode

% Frequencies stored as time steps
frequencies = exo.Time;

% Collect displacement and rotation degrees of freedom
variable_names = {'DispX','DispY','DispZ','RotX','RotY','RotZ'};
escdf_signifiers = {'X+','Y+','Z+','RX+','RY+','RZ+'};
shape_matrices = {};
dof_names = {};
for i = 1:length(variable_names)
    variable_name = variable_names{i};
    variable_index = strcmp({exo.NodalVars.Name},variable_name);
    variable_data = exo.NodalVars(variable_index).Data;
    shape_matrices{end+1} = variable_data;
    dof_names{end+1} = cellstr(string(node_ids)+escdf_signifiers{i});
end

% Stack the matrices and degree of freedom names to form a single array
% for each value
full_shape_matrix = vertcat(shape_matrices{:});
full_dof_names = vertcat(dof_names{:});

% Rotational degrees of freedom only exist at some nodes, so we can remove
% the degrees of freedom where they don't exist
empty_dofs = all(full_shape_matrix==0,2);
full_shape_matrix = full_shape_matrix(~empty_dofs,:);
full_dof_names = full_dof_names(~empty_dofs,:);

% Store the parameters into the dataset
esmode.frequency=frequencies;
esmode.shape = full_shape_matrix;
esmode.dof_name = full_dof_names;

esmode

esmode.validate()

% Populate global analysis attributes

esatt = escdf_dataset('attributes','global_analysis_attributes',...
    'Information about frame_wing_thick_v2_si-eig.exo');

esatt

% Pull information about the file from the info records and qa records
info_records = exo.InfoRecords;
qa_records = exo.QARecords;

% Populate the fields
esatt.analysis_name = {'Frame and Wing Eigensolution'};
esatt.analysis_contents = {'4-bay Frame','Straight Thick Wing'}.';
esatt.program = {'Substructuring Working Group'};
esatt.software = {[qa_records(end).CodeName,' ',qa_records(end).CodeVersion]};
esatt.point_of_contact = {'Model and Analysis: Brian Owens',...
                          'Modal Testing: Steve Carter'}.';

% The info_records contain the entire input file, so we will add it as
% the notes property
esatt.notes = info_records;

esatt

% Package the ESCDF File

% Add metadata to the ESCDF file
esfile.add_metadata(esatt);
esfile.add_metadata(esgeo);

esfile

% Pull the date from the exodus qa_records
activity_date = datetime([qa_records(end).Date,' ',qa_records(end).Time],...
    'InputFormat','yyyy/MM/dd HH:mm:ss');

% Create the activity in the ESCDF file
esfile.add_activity('eigen','Eigensolution of frame_wing_thick_v2_si-eig.exo', ...
    activity_date);

esfile

% Link activities to the metadata
esfile.link_activity_to_metadata('eigen', 'mesh_geometry')
esfile.link_activity_to_metadata('eigen', 'attributes')

esfile

% Add data to the activity
esfile.add_data_to_activity('eigen',esmode)

esfile

% Write the file to disk
esfile.write_to_disk('framewing_eigen_escdf_mat.esf',true);
