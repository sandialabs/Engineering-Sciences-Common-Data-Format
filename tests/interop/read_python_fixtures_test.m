classdef read_python_fixtures_test < matlab.unittest.TestCase

    methods (Static)
        function verifyDatetimesNearlyEqual(testCase, actual, expected, tol_seconds)
            if nargin < 4
                tol_seconds = 1e-6;
            end
            testCase.verifyLessThan(seconds(abs(actual - expected)), tol_seconds);
        end
    end

    methods (Test)
        function test_read_python_simple_scalar_fixture(testCase)
            this_file_dir = fileparts(mfilename('fullpath'));
            repo_root = char(java.io.File(fullfile(this_file_dir, '..', '..')).getCanonicalPath());
            addpath(fullfile(repo_root, "escdf"));

            file_path = fullfile( ...
                repo_root, ...
                "ci_artifacts", ...
                "interop", ...
                "python_written", ...
                "simple_scalar_python_written.h5");

            loaded = escdf.load(file_path);

            metadata = loaded.get_metadata();
            testCase.verifyEqual(numel(metadata), 1);
            testCase.verifyEqual(metadata(1).get_name(), 'global_meta');

            md = loaded.get_metadata('global_meta');
            testCase.verifyEqual(md.get_type(), 'global_test_attributes');
            testCase.verifyEqual(md.get_descriptive_name(), 'Global test metadata');
            testCase.verifyEqual(md.test_name(:), {'Qualification Test'});
            testCase.verifyEqual(md.program(:), {'Program ABC'});
            testCase.verifyEqual(md.hardware_list(:), {'hardware_1'; 'hardware_2'});
            testCase.verifyEqual(md.point_of_contact(:), {'person_1'; 'person_2'});

            activities = loaded.get_activity();
            testCase.verifyEqual(numel(activities), 1);
            testCase.verifyEqual(activities(1).get_name(), 'act1');

            act = loaded.get_activity('act1');
            testCase.verifyEqual(act.get_descriptive_name(), 'Activity One');
            expected_activity_time = datetime(2025,6,7,8,9,10.654321,'TimeZone','UTC');
            read_python_fixtures_test.verifyDatetimesNearlyEqual( ...
                testCase, act.get_date(), expected_activity_time);

            testCase.verifyEqual(act.get_metadata_links(), {'global_meta'});
            testCase.verifyEqual(act.get_data_names(), {'scalar_result'});

            data = loaded.get_activity_data('act1', 'scalar_result');
            testCase.verifyEqual(data.get_type(), 'scalar');
            testCase.verifyEqual(data.get_descriptive_name(), 'Scalar activity result');
            testCase.verifyEqual(double(data.value(:)), 9.81);
            testCase.verifyEqual(data.unit(:), {'m/s^2'});

            created_date_raw = h5readatt(file_path, '/', 'created_date');
            testCase.verifyEqual(created_date_raw, '2025-01-02T03:04:05.123456Z');
        end

        function test_read_python_numeric_arrays_fixture(testCase)
            this_file_dir = fileparts(mfilename('fullpath'));
            repo_root = char(java.io.File(fullfile(this_file_dir, '..', '..')).getCanonicalPath());
            addpath(fullfile(repo_root, "escdf"));

            file_path = fullfile( ...
                repo_root, ...
                "ci_artifacts", ...
                "interop", ...
                "python_written", ...
                "numeric_arrays_python_written.h5");

            loaded = escdf.load(file_path);

            metadata = loaded.get_metadata();
            testCase.verifyEqual(numel(metadata), 1);
            testCase.verifyEqual(metadata(1).get_name(), 'geometry_meta');

            md = loaded.get_metadata('geometry_meta');
            testCase.verifyEqual(md.get_type(), 'geometry');
            testCase.verifyEqual(md.get_descriptive_name(), 'Geometry metadata');
            testCase.verifyEqual(md.node_id(:), uint64([10;20;30]));
            testCase.verifyEqual(md.node_position(:,:), [
                0.0 0.0 0.0
                1.0 0.0 0.0
                0.0 1.0 0.0
            ]);
            testCase.verifyEqual(md.node_x_direction(:,:), [
                1.0 0.0 0.0
                1.0 0.0 0.0
                1.0 0.0 0.0
            ]);
            testCase.verifyEqual(md.node_y_direction(:,:), [
                0.0 1.0 0.0
                0.0 1.0 0.0
                0.0 1.0 0.0
            ]);
            testCase.verifyEqual(md.node_z_direction(:,:), [
                0.0 0.0 1.0
                0.0 0.0 1.0
                0.0 0.0 1.0
            ]);
            testCase.verifyEqual(md.position_units(:), {'m'});

            activities = loaded.get_activity();
            testCase.verifyEqual(numel(activities), 1);
            testCase.verifyEqual(activities(1).get_name(), 'act_arrays');

            act = loaded.get_activity('act_arrays');
            testCase.verifyEqual(act.get_descriptive_name(), 'Array activity');
            expected_activity_time = datetime(2025,8,9,10,11,12.345678,'TimeZone','UTC');
            read_python_fixtures_test.verifyDatetimesNearlyEqual( ...
                testCase, act.get_date(), expected_activity_time);

            testCase.verifyEqual(act.get_metadata_links(), {'geometry_meta'});
            testCase.verifyEqual(sort(act.get_data_names()), {'matrix_result','vector_result'});

            vector_result = loaded.get_activity_data('act_arrays', 'vector_result');
            testCase.verifyEqual(vector_result.get_type(), 'vector');
            testCase.verifyEqual(double(vector_result.value(:)), [1.0;2.0;3.5;4.5]);
            testCase.verifyEqual(vector_result.unit(:), {'m/s^2'});

            matrix_result = loaded.get_activity_data('act_arrays', 'matrix_result');
            testCase.verifyEqual(matrix_result.get_type(), 'matrix');
            testCase.verifyEqual(double(matrix_result.value(:,:)), [
                1.0 2.0
                3.0 4.5
                6.0 7.0
            ]);
            testCase.verifyEqual(matrix_result.unit(:), {'N'});
        end

        function test_read_python_invalid_names_fixture(testCase)
            this_file_dir = fileparts(mfilename('fullpath'));
            repo_root = char(java.io.File(fullfile(this_file_dir, '..', '..')).getCanonicalPath());
            addpath(fullfile(repo_root, "escdf"));

            file_path = fullfile( ...
                repo_root, ...
                "ci_artifacts", ...
                "interop", ...
                "python_written", ...
                "invalid_names_python_written.h5");

            loaded = escdf.load(file_path);

            metadata = loaded.get_metadata();
            testCase.verifyEqual(numel(metadata), 1);
            testCase.verifyEqual(metadata(1).get_name(), 'dataset_1_badmeta');

            md = loaded.get_metadata('dataset_1_badmeta');
            testCase.verifyEqual(md.get_type(), 'scalar');
            testCase.verifyEqual(md.get_descriptive_name(), 'Bad metadata');
            testCase.verifyEqual(double(md.value(:)), 1.23);
            testCase.verifyEqual(md.unit(:), {'g'});

            activities = loaded.get_activity();
            testCase.verifyEqual(numel(activities), 1);
            testCase.verifyEqual(activities(1).get_name(), 'activity_1_badactivity');

            act = loaded.get_activity('activity_1_badactivity');
            testCase.verifyEqual(act.get_descriptive_name(), 'Bad activity');
            expected_activity_time = datetime(2025,9,10,11,12,13.222222,'TimeZone','UTC');
            read_python_fixtures_test.verifyDatetimesNearlyEqual( ...
                testCase, act.get_date(), expected_activity_time);

            testCase.verifyEqual(act.get_metadata_links(), {'dataset_1_badmeta'});

            created_date_raw = h5readatt(file_path, '/', 'created_date');
            testCase.verifyEqual(created_date_raw, '2025-04-05T06:07:08.111111Z');
        end


        function test_read_python_unknown_type_fixture(testCase)
            this_file_dir = fileparts(mfilename('fullpath'));
            repo_root = char(java.io.File(fullfile(this_file_dir, '..', '..')).getCanonicalPath());
            addpath(fullfile(repo_root, "escdf"));

            file_path = fullfile( ...
                repo_root, ...
                "ci_artifacts", ...
                "interop", ...
                "python_written", ...
                "unknown_type_python_written.h5");

            loaded = escdf.load(file_path);

            metadata = loaded.get_metadata();
            testCase.verifyEqual(numel(metadata), 1);
            testCase.verifyEqual(metadata(1).get_name(), 'mystery_metadata');

            md = loaded.get_metadata('mystery_metadata');
            testCase.verifyEqual(md.get_type(), 'unknown');
            testCase.verifyEqual(md.get_descriptive_name(), 'Mystery metadata');
            testCase.verifyEqual(md.original_type_name(:), {'totally_unknown_type'});

            activities = loaded.get_activity();
            testCase.verifyEqual(numel(activities), 0);

            created_date_raw = h5readatt(file_path, '/', 'created_date');
            testCase.verifyEqual(created_date_raw, '2025-04-05T06:07:08.333333Z');
        end

        function test_read_python_attachments_bytes_fixture(testCase)
            this_file_dir = fileparts(mfilename('fullpath'));
            repo_root = char(java.io.File(fullfile(this_file_dir, '..', '..')).getCanonicalPath());
            addpath(fullfile(repo_root, "escdf"));

            file_path = fullfile( ...
                repo_root, ...
                "ci_artifacts", ...
                "interop", ...
                "python_written", ...
                "attachments_bytes_python_written.h5");

            loaded = escdf.load(file_path);

            metadata = loaded.get_metadata();
            testCase.verifyEqual(numel(metadata), 1);
            testCase.verifyEqual(metadata(1).get_name(), 'global_meta_with_attachments');

            md = loaded.get_metadata('global_meta_with_attachments');
            testCase.verifyEqual(md.get_type(), 'global_test_attributes');
            testCase.verifyEqual(md.get_descriptive_name(), 'Global metadata with attachments');
            testCase.verifyEqual(md.test_name(:), {'Attachment Test'});
            testCase.verifyEqual(md.program(:), {'Program Bytes'});
            testCase.verifyEqual(md.hardware_list(:), {'hardware_1'});
            testCase.verifyEqual(md.point_of_contact(:), {'person_1'});
            testCase.verifyEqual(md.attachment_names(:), {'hello.bin'; 'numbers.bin'});

            attachments = md.attachments(:);
            testCase.verifyEqual(numel(attachments), 2);
            testCase.verifyEqual(attachments{1}, uint8('hello world').');
            testCase.verifyEqual(attachments{2}, uint8([1;2;3;4;5;255]));

            activities = loaded.get_activity();
            testCase.verifyEqual(numel(activities), 0);

            created_date_raw = h5readatt(file_path, '/', 'created_date');
            testCase.verifyEqual(created_date_raw, '2025-05-06T07:08:09.444444Z');
        end

        function test_read_python_complex_data_fixture(testCase)
            this_file_dir = fileparts(mfilename('fullpath'));
            repo_root = char(java.io.File(fullfile(this_file_dir, '..', '..')).getCanonicalPath());
            addpath(fullfile(repo_root, "escdf"));

            file_path = fullfile( ...
                repo_root, ...
                "ci_artifacts", ...
                "interop", ...
                "python_written", ...
                "complex_data_python_written.h5");

            loaded = escdf.load(file_path);

            metadata = loaded.get_metadata();
            testCase.verifyEqual(numel(metadata), 0);

            activities = loaded.get_activity();
            testCase.verifyEqual(numel(activities), 1);
            testCase.verifyEqual(activities(1).get_name(), 'act_complex');

            act = loaded.get_activity('act_complex');
            testCase.verifyEqual(act.get_descriptive_name(), 'Complex activity');
            expected_activity_time = datetime(2025,10,12,13,14,15.666666,'TimeZone','UTC');
            read_python_fixtures_test.verifyDatetimesNearlyEqual( ...
                testCase, act.get_date(), expected_activity_time);

            testCase.verifyEqual(sort(act.get_data_names()), ...
                {'complex_matrix_result','complex_scalar_result','complex_vector_result'});

            scalar_result = loaded.get_activity_data('act_complex', 'complex_scalar_result');
            testCase.verifyEqual(scalar_result.get_type(), 'scalar');
            testCase.verifyEqual(real(double(scalar_result.value(:))), 1.5);
            testCase.verifyEqual(imag(double(scalar_result.value(:))), -2.25);
            testCase.verifyEqual(scalar_result.unit(:), {'V'});

            vector_result = loaded.get_activity_data('act_complex', 'complex_vector_result');
            testCase.verifyEqual(vector_result.get_type(), 'vector');
            testCase.verifyEqual(double(vector_result.value(:)), [
                1.0 + 2.0j
                -3.0 + 0.5j
                -1.0j
                4.25 + 3.0j
            ]);
            testCase.verifyEqual(vector_result.unit(:), {'m/s'});

            matrix_result = loaded.get_activity_data('act_complex', 'complex_matrix_result');
            testCase.verifyEqual(matrix_result.get_type(), 'matrix');
            testCase.verifyEqual(double(matrix_result.value(:,:)), [
                1.0 + 1.0j, 2.0 - 2.0j
                -3.0 + 0.5j, 4.0 + 4.0j
                -1.0j, 6.0 + 0.0j
            ]);
            testCase.verifyEqual(matrix_result.unit(:), {'N'});

            created_date_raw = h5readatt(file_path, '/', 'created_date');
            testCase.verifyEqual(created_date_raw, '2025-10-11T12:13:14.555555Z');
        end

        function test_read_python_ragged_numeric_fixture(testCase)
            this_file_dir = fileparts(mfilename('fullpath'));
            repo_root = char(java.io.File(fullfile(this_file_dir, '..', '..')).getCanonicalPath());
            addpath(fullfile(repo_root, "escdf"));

            file_path = fullfile( ...
                repo_root, ...
                "ci_artifacts", ...
                "interop", ...
                "python_written", ...
                "ragged_numeric_python_written.h5");

            loaded = escdf.load(file_path);

            metadata = loaded.get_metadata();
            testCase.verifyEqual(numel(metadata), 1);
            testCase.verifyEqual(metadata(1).get_name(), 'geometry_ragged_meta');

            md = loaded.get_metadata('geometry_ragged_meta');
            testCase.verifyEqual(md.get_type(), 'geometry');
            testCase.verifyEqual(md.get_descriptive_name(), 'Geometry with ragged connectivity');

            testCase.verifyEqual(md.node_id(:), uint64([10;20;30;40;50]));
            testCase.verifyEqual(md.node_position(:,:), [
                0.0 0.0 0.0
                1.0 0.0 0.0
                2.0 0.5 0.0
                3.0 1.0 0.0
                4.0 1.5 0.0
            ]);

            line_connection = md.line_connection(:);
            testCase.verifyEqual(numel(line_connection), 3);
            testCase.verifyEqual(line_connection{1}(:), uint64([10;20]));
            testCase.verifyEqual(line_connection{2}(:), uint64([20;30;40]));
            testCase.verifyEqual(line_connection{3}(:), uint64([40;50]));

            element_connection = md.element_connection(:);
            testCase.verifyEqual(numel(element_connection), 2);
            testCase.verifyEqual(element_connection{1}(:), uint64([10;20;30]));
            testCase.verifyEqual(element_connection{2}(:), uint64([20;30;40;50]));

            testCase.verifyEqual(md.element_type(:), {'tri3'; 'quad4'});
            testCase.verifyEqual(md.position_units(:), {'m'});

            activities = loaded.get_activity();
            testCase.verifyEqual(numel(activities), 0);

            created_date_raw = h5readatt(file_path, '/', 'created_date');
            testCase.verifyEqual(created_date_raw, '2025-11-01T02:03:04.777777Z');
        end

        function test_read_python_extra_property_fixture(testCase)
            this_file_dir = fileparts(mfilename('fullpath'));
            repo_root = char(java.io.File(fullfile(this_file_dir, '..', '..')).getCanonicalPath());
            addpath(fullfile(repo_root, "escdf"));

            file_path = fullfile( ...
                repo_root, ...
                "ci_artifacts", ...
                "interop", ...
                "python_written", ...
                "extra_property_python_written.h5");

            loaded = escdf.load(file_path);

            metadata = loaded.get_metadata();
            testCase.verifyEqual(numel(metadata), 1);
            testCase.verifyEqual(metadata(1).get_name(), 'meta_with_extra');

            md = loaded.get_metadata('meta_with_extra');
            testCase.verifyEqual(md.get_type(), 'scalar');
            testCase.verifyEqual(md.get_descriptive_name(), 'Scalar metadata with extra field');
            testCase.verifyEqual(double(md.unexpected_field(:)), [10;20;30]);
            testCase.verifyFalse(md.validate());
        end

        function test_extract_attachments_from_python_fixture(testCase)
            this_file_dir = fileparts(mfilename('fullpath'));
            repo_root = char(java.io.File(fullfile(this_file_dir, '..', '..')).getCanonicalPath());
            addpath(fullfile(repo_root, "escdf"));

            file_path = fullfile( ...
                repo_root, ...
                "ci_artifacts", ...
                "interop", ...
                "python_written", ...
                "attachments_bytes_python_written.h5");

            loaded = escdf.load(file_path);
            md = loaded.get_metadata('global_meta_with_attachments');

            output_dir = fullfile(repo_root, "ci_artifacts", "interop", "matlab_extracted_attachments");
            if ~isfolder(output_dir)
                mkdir(output_dir);
            end

            md.dump_attachments_to_disk(output_dir);

            hello_path = fullfile(output_dir, 'hello.bin');
            numbers_path = fullfile(output_dir, 'numbers.bin');

            testCase.verifyTrue(isfile(hello_path));
            testCase.verifyTrue(isfile(numbers_path));

            fid = fopen(hello_path, 'r');
            hello_bytes = fread(fid, inf, '*uint8');
            fclose(fid);

            fid = fopen(numbers_path, 'r');
            numbers_bytes = fread(fid, inf, '*uint8');
            fclose(fid);

            testCase.verifyEqual(hello_bytes(:), uint8('hello world').');
            testCase.verifyEqual(numbers_bytes(:), uint8([1;2;3;4;5;255]));
        end

    end
end