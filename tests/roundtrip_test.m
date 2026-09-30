classdef roundtrip_test < matlab.unittest.TestCase

    properties
        temp_folder
        original_path
        source_folder
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
        function teardownEnvironment(testCase)
            if isfolder(testCase.temp_folder)
                rmdir(testCase.temp_folder, 's');
            end
            path(testCase.original_path);
        end
    end

    methods (Static)

        function verifyDatetimesNearlyEqual(testCase, actual, expected, tol_seconds)
            if nargin < 4
                tol_seconds = 1e-6;
            end
            testCase.verifyLessThan(seconds(abs(actual - expected)), tol_seconds);
        end

        function ds = make_global_test_attributes(name)
            ds = escdf_dataset(name, 'global_test_attributes', 'Global test metadata');
            ds.test_name = {'Qualification Test'};
            ds.program = {'Program ABC'};
            ds.hardware_list = {'hardware_1'; 'hardware_2'};
            ds.point_of_contact = {'person_1'; 'person_2'};
        end

        function ds = make_geometry(name)
            ds = escdf_dataset(name, 'geometry', 'Geometry metadata');
            ds.node_id = uint64([10;20;30]);
            ds.node_position = [
                0.0 0.0 0.0
                1.0 0.0 0.0
                0.0 1.0 0.0
            ];
            ds.node_x_direction = [
                1.0 0.0 0.0
                1.0 0.0 0.0
                1.0 0.0 0.0
            ];
            ds.node_y_direction = [
                0.0 1.0 0.0
                0.0 1.0 0.0
                0.0 1.0 0.0
            ];
            ds.node_z_direction = [
                0.0 0.0 1.0
                0.0 0.0 1.0
                0.0 0.0 1.0
            ];
            ds.position_units = {'m'};
        end

        function ds = make_scalar_data(name, value, unit)
            ds = escdf_dataset(name, 'scalar', 'Scalar activity result');
            ds.value = value;
            ds.unit = {unit};
        end

        function ds = make_vector_data(name)
            ds = escdf_dataset(name, 'vector', 'Vector activity result');
            ds.value = [1.0; 2.0; 3.5; 4.5];
            ds.unit = {'m/s^2'};
        end

        function ds = make_matrix_data(name)
            ds = escdf_dataset(name, 'matrix', 'Matrix activity result');
            ds.value = [
                1.0 2.0
                3.0 4.5
                6.0 7.0
            ];
            ds.unit = {'N'};
        end
    end

    methods (Test)

        function test_full_roundtrip_multiple_metadata_and_activities(testCase)
            outfile = fullfile(testCase.temp_folder, 'full_roundtrip.h5');

            original = escdf();

            md_global = roundtrip_test.make_global_test_attributes('global_meta');
            md_geometry = roundtrip_test.make_geometry('geometry_meta');

            testCase.verifyTrue(md_global.validate());
            testCase.verifyTrue(md_geometry.validate());

            original.add_metadata(md_global);
            original.add_metadata(md_geometry);

            time1 = datetime(2024,1,2,3,4,5.123456,'TimeZone','UTC');
            time2 = datetime(2024,6,7,8,9,10.654321,'TimeZone','UTC');

            original.add_activity('act1', 'First activity', time1);
            original.add_activity('act2', 'Second activity', time2);

            original.link_activity_to_metadata('act1', 'global_meta');
            original.link_activity_to_metadata('act1', 'geometry_meta');
            original.link_activity_to_metadata('act2', 'global_meta');

            original.add_data_to_activity('act1', roundtrip_test.make_scalar_data('scalar_result', 9.81, 'm/s^2'));
            original.add_data_to_activity('act1', roundtrip_test.make_vector_data('vector_result'));
            original.add_data_to_activity('act2', roundtrip_test.make_matrix_data('matrix_result'));

            original.write_to_disk(outfile, true);

            loaded = escdf.load(outfile);

            metadata = loaded.get_metadata();
            metadata_names = sort(arrayfun(@(x) x.get_name(), metadata, 'UniformOutput', false));
            testCase.verifyEqual(metadata_names, {'geometry_meta','global_meta'});

            loaded_global = loaded.get_metadata('global_meta');
            testCase.verifyEqual(loaded_global.get_type(), 'global_test_attributes');
            testCase.verifyEqual(loaded_global.get_descriptive_name(), 'Global test metadata');
            testCase.verifyEqual(loaded_global.test_name(:), {'Qualification Test'});
            testCase.verifyEqual(loaded_global.program(:), {'Program ABC'});
            testCase.verifyEqual(loaded_global.hardware_list(:), {'hardware_1';'hardware_2'});
            testCase.verifyEqual(loaded_global.point_of_contact(:), {'person_1';'person_2'});

            loaded_geometry = loaded.get_metadata('geometry_meta');
            testCase.verifyEqual(loaded_geometry.get_type(), 'geometry');
            testCase.verifyEqual(loaded_geometry.node_id(:), uint64([10;20;30]));
            testCase.verifyEqual(loaded_geometry.position_units(:), {'m'});
            testCase.verifyEqual(loaded_geometry.node_position(:,:), [
                0.0 0.0 0.0
                1.0 0.0 0.0
                0.0 1.0 0.0
            ]);

            activities = loaded.get_activity();
            activity_names = sort(arrayfun(@(x) x.get_name(), activities, 'UniformOutput', false));
            testCase.verifyEqual(activity_names, {'act1','act2'});

            act1 = loaded.get_activity('act1');
            act2 = loaded.get_activity('act2');

            testCase.verifyEqual(act1.get_descriptive_name(), 'First activity');
            testCase.verifyEqual(act2.get_descriptive_name(), 'Second activity');
            roundtrip_test.verifyDatetimesNearlyEqual(testCase, act1.get_date(), time1);
            roundtrip_test.verifyDatetimesNearlyEqual(testCase, act2.get_date(), time2);

            testCase.verifyEqual(sort(act1.get_metadata_links()), {'geometry_meta','global_meta'});
            testCase.verifyEqual(sort(act2.get_metadata_links()), {'global_meta'});

            testCase.verifyEqual(sort(act1.get_data_names()), {'scalar_result','vector_result'});
            testCase.verifyEqual(sort(act2.get_data_names()), {'matrix_result'});

            scalar_result = loaded.get_activity_data('act1', 'scalar_result');
            testCase.verifyEqual(scalar_result.get_type(), 'scalar');
            testCase.verifyEqual(scalar_result.value(:), 9.81);
            testCase.verifyEqual(scalar_result.unit(:), {'m/s^2'});

            vector_result = loaded.get_activity_data('act1', 'vector_result');
            testCase.verifyEqual(double(vector_result.value(:)), [1.0;2.0;3.5;4.5]);
            testCase.verifyEqual(vector_result.unit(:), {'m/s^2'});
            
            matrix_result = loaded.get_activity_data('act2', 'matrix_result');
            testCase.verifyEqual(double(matrix_result.value(:,:)), [
                1.0 2.0
                3.0 4.5
                6.0 7.0
            ]);
            testCase.verifyEqual(matrix_result.unit(:), {'N'});
        end

        function test_roundtrip_preserves_created_and_activity_timestamps(testCase)
            outfile = fullfile(testCase.temp_folder, 'timestamps_roundtrip.h5');

            f = escdf();
            created_time = datetime(2025,2,3,4,5,6.789123,'TimeZone','UTC');
            activity_time = datetime(2025,7,8,9,10,11.456789,'TimeZone','UTC');

            f.set_created_properties('unit_test_user', created_time);
            f.add_activity('act1', 'Activity', activity_time);
            f.write_to_disk(outfile, true);

            loaded = escdf.load(outfile);

            activity = loaded.get_activity('act1');
            roundtrip_test.verifyDatetimesNearlyEqual(testCase, activity.get_date(), activity_time);

            created_date_raw = h5readatt(outfile, '/', 'created_date');
            expected_created_string = escdf.datetime_to_iso_utc(created_time);
            testCase.verifyEqual(created_date_raw, expected_created_string);
        end

        function test_roundtrip_writes_expected_timestamp_strings(testCase)
            outfile = fullfile(testCase.temp_folder, 'schema_check.h5');

            f = escdf();
            created_time = datetime(2025,1,2,3,4,5.123456,'TimeZone','UTC');
            activity_time = datetime(2025,6,7,8,9,10.654321,'TimeZone','UTC');

            f.set_created_properties('unit_test_user', created_time);
            f.add_activity('act1', 'Activity', activity_time);
            f.write_to_disk(outfile, true);

            created_date_raw = h5readatt(outfile, '/', 'created_date');
            activity_date_raw = h5readatt(outfile, '/activities/act1', 'activity_date');

            testCase.verifyEqual(created_date_raw, escdf.datetime_to_iso_utc(created_time));
            testCase.verifyEqual(activity_date_raw, escdf.datetime_to_iso_utc(activity_time));
        end
    end
end