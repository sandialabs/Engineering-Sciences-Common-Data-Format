% Flatten and Unflatten 3+ Dimensional Data with ESCDF

% Clear the workspace
clear; clc; close all;

% If you don't have ESCDF on your path, uncomment the following addpath 
% function and point it to the correct path

% addpath(genpath('/path/to/escdf'));

% Load in the 3-Dimensional Data
load_data = load('Example_CPSD_Data.mat');

load_data

% Create an empty ESCDF file that we will populate
escdf_file = escdf();

escdf_file

disp(fileread('data.txt'))

% Create an empty structure that we will populate with the unflattened data
unflattened_data = dump_to_struct(escdf_dataset('temp','data','example cpsd data'));

unflattened_data

% Populate the abscissa (frequency) and ordinate (CPSD) fields of the
% unflattened data structure
unflattened_data.ordinate = load_data.ordinate;
unflattened_data.abscissa = load_data.abscissa;

% Populate the data_type field with a compatible and correct option from the
% enumerations list
unflattened_data.data_type = {'power spectral density'};

% Populate the abscissa_unit and ordinate_unit fields as scalars, when the same
% unit can describe all the data.
unflattened_data.abscissa_unit = {'Hz'};
unflattened_data.ordinate_unit = {'G^2/Hz'};

% Initialize the ordinate_unit cell array with the same dimensions as the
% ordinate (excluding the abscissa dimension).
unflattened_data.ordinate_unit = cell(size(unflattened_data.ordinate,1:ndims(unflattened_data.ordinate)-1));

% Populate the first N-12 rows and columns of ordinate_unit with their
% appropriate units (G^2/Hz for our example CPSD data)
unflattened_data.ordinate_unit(1:end-12,1:end-12) = {'G^2/Hz'};

% Populate the last 12 rows for the first N-12 columns, and the last 12 columns
% for the first N-12 rows with their appropriate units (we assign G^2/Hz for
% our example CPSD data, but if the last 12 channels were voltage, this unit
% would be G-V/Hz)
unflattened_data.ordinate_unit(end-11:end,1:end-12) = {'G^2/Hz'};
unflattened_data.ordinate_unit(1:end-12,end-11:end) = {'G^2/Hz'};

% Populate the last 12 rows and columns of ordinate_unit with their appropriate
% units (we assign G^2/Hz for our example CPSD data, but if the last 12
% channels were voltage, this unit would be V^2/Hz).
unflattened_data.ordinate_unit(end-11:end,end-11:end) = {'G^2/Hz'};

% Extract the nodes from the example data and convert them to strings since the
% channel field is defined by a cell array of strings
nodes = strtrim(cellstr(num2str(load_data.node,'%d')));

% Extract the node directions and polarities from the example data. Note, it
% should not be assumed that these directions correspond to the local
% coordinate frame or the global coordinate frame. Instead, a geometry metadata
% object that maps these node directions to our physical geometry should
% reviewed to understand the directions actually measured by each channel. This
% is beyond the scope of the current example.
directions = load_data.direction;

% Define the channel names by concatenating the nodes, directions, and
% polarities together which conforms to how ESCDF requires them based on the
% regex option of the channel property in the specification file.
channels = strcat(nodes,directions);

% Populate the channel field as a cell array containing a cell of channel names
% for each respective dimension, which in the CPSD example are the exact same
% for each dimension.
unflattened_data.channel = {channels, channels};

% Flatten the unflattened data structure using the ESCDF flatten_data()
% function
flattened_data = escdf_dataset.flatten_data(unflattened_data);

flattened_data

% Create the ESCDF data object from the flattened data structure
data = escdf_dataset.build_from_struct('cpsd',flattened_data);

data

% Pull the date from the last modified date of the source file
file_info = dir('Example_CPSD_Data.mat');
activity_date = datetime(file_info.date);

% Create the activity in the ESCDF file
escdf_file.add_activity('Environment','Response of test article to environment from Example_CPSD_Data.mat',activity_date);

escdf_file

% Add data to the activity
escdf_file.add_data_to_activity('Environment',data)

escdf_file

% Write the file to disk
escdf_file.write_to_disk('Example_CPSD_Data.h5',true);

% Load in the example flattened CPSD data
escdf_file = escdf.load('Example_CPSD_Data.h5');

escdf_file

% Extract the flattened CPSD data
data = escdf_file.activities(1).data(1);

% Dump the flattened data to a structure from the ESCDF data object
flattened_data = data.dump_to_struct();

flattened_data

% Unflatten the flattened data structure using the ESCDF unflatten_data()
% function
unflattened_data = escdf_dataset.unflatten_data(flattened_data);

unflattened_data
