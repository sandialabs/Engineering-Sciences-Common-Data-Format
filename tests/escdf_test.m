classdef escdf_test < matlab.unittest.TestCase
    properties
        temp_folder;
        original_path;
        source_folder;
    end

    methods (TestMethodSetup)
        function setupEnvironment(testCase)
            current_file_folder = fileparts(mfilename('fullpath'));
            testCase.source_folder = fullfile(current_file_folder, '..', 'escdf');
            testCase.temp_folder = tempname;
            testCase.original_path = addpath(testCase.source_folder);
            mkdir(testCase.temp_folder);
        end
    end

    methods (TestMethodTeardown)
        function deleteStoredData(testCase)
            rmdir(testCase.temp_folder,'s');
            path(testCase.original_path);
        end
    end

    methods (Test)
        function testCreationStorageReading(testCase)
            outfile = fullfile(testCase.temp_folder,'test.h5');
            activity_time = datetime(2020,1,15);
            escdf_file = escdf();
            testCase.verifyTrue(isempty(escdf_file.activities));
            testCase.verifyTrue(isempty(escdf_file.metadata));
            geometry = escdf_dataset('test_geometry','geometry','Test Geometry Descriptive Name');
            geometry.node_id = randi(100,[5,1]);
            geometry.node_position = randn(5,3);
            geometry.node_x_direction = randn(5,3);
            geometry.node_y_direction = randn(5,3);
            geometry.node_z_direction = randn(5,3);
            geometry.line_color = randi(255,[1,3]);
            geometry.line_connection = {geometry.node_id(:)};
            geometry.position_units = {'m'};
            testCase.verifyTrue(geometry.validate());
            global_parameters = escdf_dataset('test_attributes','global_test_attributes','Global Parameters Descriptive Name');
            global_parameters.hardware_list = {'Hardware 1','Hardware 2'}.';
            global_parameters.point_of_contact = {'Joe Shmo','Debbie Downer'}.';
            global_parameters.program = {'test program'};
            global_parameters.test_name = {'test test'};
            testCase.verifyTrue(global_parameters.validate());
            channel_table = escdf_dataset('channel_table','vibration_channel_table','Channels contained in the test');
            channel_table.description = {'Sensor 1','Sensor 2','Sensor 3'}.';
            channel_table.node_id = [1,2,3].';
            channel_table.node_direction = {'X+','Y+','Z+'}.';
            channel_table.make = {'PCB','PCB','PCB'}.';
            channel_table.model = {'352A71','352A71','352A71'}.';
            channel_table.serial_number = {'100','101','102'}.';
            channel_table.sensitivity = [10,10,10].';
            channel_table.sensitivity_unit = {'G','G','G'}.';
            channel_table.daq = {'LAN-XI','LAN-XI','LAN-XI'}.';
            channel_table.data_type = {'acceleration','acceleration','acceleration'}.';
            channel_table.coupling = {'iepe','iepe','iepe'}.';
            testCase.verifyTrue(channel_table.validate());
            data = escdf_dataset('test_data','data','Test Data Descriptive Name').';
            data.abscissa_start = 0;
            data.abscissa_step = 0.001;
            data.abscissa_unit = {'s'};
            data.ordinate = randn([10,1000]);
            data.ordinate_unit = {'G','G','G','G','G','lbf','lbf','lbf','lbf','lbf'}.';
            data.data_type = {'time response'};
            data.channel = {'1X+','2X+','3X+','4X+','5X+','6X+','7X+','8X+','9X+','10X+'}.';
            testCase.verifyTrue(data.validate())
            data2 = escdf_dataset('test_data2','data','Test Data Descriptive Name').';
            data2.abscissa_start = 0;
            data2.abscissa_step = 0.001;
            data2.abscissa_unit = {'s'};
            data2.ordinate = randn([10,1000]);
            data2.ordinate_unit = {'G','G','G','G','G','lbf','lbf','lbf','lbf','lbf'}.';
            data2.data_type = {'time response'};
            data2.channel = {'1X+','2X+','3X+','4X+','5X+','6X+','7X+','8X+','9X+','10X+'}.';
            testCase.verifyTrue(data2.validate());
            escdf_file.add_activity('test_activity','Testing Activity Stuff',activity_time);
            escdf_file.add_data_to_activity('test_activity',data);
            escdf_file.add_data_to_activity('test_activity',data2);
            escdf_file.add_metadata(global_parameters);
            escdf_file.add_metadata(geometry);
            escdf_file.add_metadata(channel_table);
            escdf_file.link_activity_to_metadata('test_activity','test_geometry');
            escdf_file.link_activity_to_metadata('test_activity','test_attributes');
            escdf_file.link_activity_to_metadata('test_activity','channel_table');
        end
    end

end