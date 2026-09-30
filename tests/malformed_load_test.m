classdef malformed_load_test < matlab.unittest.TestCase

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

        function write_string_attribute(loc_id, attr_name, value)
            attr_space_id = H5S.create('H5S_SCALAR');
            str_type_id = H5T.copy('H5T_C_S1');
            H5T.set_size(str_type_id, 'H5T_VARIABLE');
            attr_id = H5A.create(loc_id, attr_name, str_type_id, attr_space_id, 'H5P_DEFAULT');
            H5A.write(attr_id, str_type_id, value);
            H5A.close(attr_id);
            H5T.close(str_type_id);
            H5S.close(attr_space_id);
        end

        function write_version_attribute(loc_id, version_numbers)
            attr_type = H5T.copy('H5T_NATIVE_INT');
            attr_space = H5S.create_simple(1, numel(version_numbers), []);
            attr_id = H5A.create(loc_id, '_version', attr_type, attr_space, 'H5P_DEFAULT', 'H5P_DEFAULT');
            H5A.write(attr_id, attr_type, int32(version_numbers));
            H5A.close(attr_id);
            H5S.close(attr_space);
        end

        function create_minimal_scalar_group(parent_id, name, dataset_type, descriptive_name)
            gid = H5G.create(parent_id, name, 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');

            malformed_load_test.write_string_attribute(gid, '_specification_name', dataset_type);

            if ~isempty(descriptive_name)
                malformed_load_test.write_string_attribute(gid, '_descriptive_name', descriptive_name);
            end

            malformed_load_test.write_version_attribute(gid, [0 1 0]);

            % value dataset
            value_space = H5S.create('H5S_SCALAR');
            value_did = H5D.create(gid, 'value', 'H5T_IEEE_F64LE', value_space, 'H5P_DEFAULT');
            H5D.write(value_did, 'H5T_IEEE_F64LE', 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', 1.25);
            malformed_load_test.write_string_attribute(value_did, 'data_type', 'f8');
            H5D.close(value_did);
            H5S.close(value_space);

            % unit dataset
            unit_space = H5S.create('H5S_SCALAR');
            str_type_id = H5T.copy('H5T_C_S1');
            H5T.set_size(str_type_id, 'H5T_VARIABLE');
            unit_did = H5D.create(gid, 'unit', str_type_id, unit_space, 'H5P_DEFAULT');
            H5D.write(unit_did, str_type_id, 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', 'g');
            malformed_load_test.write_string_attribute(unit_did, 'data_type', 'str');
            H5D.close(unit_did);
            H5T.close(str_type_id);
            H5S.close(unit_space);

            H5G.close(gid);
        end
    end

    methods (Test)

        function test_load_missing_created_by_defaults(testCase)
            outfile = fullfile(testCase.temp_folder, 'missing_created_by.h5');
            file_id = H5F.create(outfile, 'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');

            malformed_load_test.write_string_attribute(file_id, 'created_date', '2024-01-02T03:04:05.123456Z');
            H5G.create(file_id, 'activities', 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');

            H5F.close(file_id);

            loaded = escdf.load(outfile);
            s = evalc('disp(loaded)');
            testCase.verifyNotEmpty(s);
            testCase.verifyTrue(contains(s, 'UNKNOWN'));
        end

        function test_load_missing_created_date_defaults(testCase)
            outfile = fullfile(testCase.temp_folder, 'missing_created_date.h5');
            file_id = H5F.create(outfile, 'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');

            malformed_load_test.write_string_attribute(file_id, 'created_by', 'someone');
            H5G.create(file_id, 'activities', 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');

            H5F.close(file_id);

            loaded = escdf.load(outfile);
            s = evalc('disp(loaded)');
            testCase.verifyNotEmpty(s);
            testCase.verifyTrue(contains(s, 'someone'));
        end

        function test_load_missing_activity_date_defaults(testCase)
            outfile = fullfile(testCase.temp_folder, 'missing_activity_date.h5');
            file_id = H5F.create(outfile, 'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');

            malformed_load_test.write_string_attribute(file_id, 'created_by', 'someone');
            malformed_load_test.write_string_attribute(file_id, 'created_date', '2024-01-02T03:04:05.123456Z');

            activities_gid = H5G.create(file_id, 'activities', 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');
            act_gid = H5G.create(activities_gid, 'act1', 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');
            malformed_load_test.write_string_attribute(act_gid, 'activity_name', 'Activity one');

            % empty parameters dataset
            space_id = H5S.create_simple(1, 0, []);
            str_type_id = H5T.copy('H5T_C_S1');
            H5T.set_size(str_type_id, 'H5T_VARIABLE');
            did = H5D.create(act_gid, 'parameters', str_type_id, space_id, 'H5P_DEFAULT');
            malformed_load_test.write_string_attribute(did, 'data_type', 'str');
            H5D.close(did);
            H5T.close(str_type_id);
            H5S.close(space_id);

            H5G.close(act_gid);
            H5G.close(activities_gid);
            H5F.close(file_id);

            loaded = escdf.load(outfile);
            activity = loaded.get_activity('act1');

            testCase.verifyEqual(activity.get_name(), 'act1');
            testCase.verifyEmpty(activity.get_metadata_links());
        end

        function test_load_unknown_dataset_type_maps_to_unknown(testCase)
            outfile = fullfile(testCase.temp_folder, 'unknown_dataset_type.h5');
            file_id = H5F.create(outfile, 'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');

            malformed_load_test.write_string_attribute(file_id, 'created_by', 'someone');
            malformed_load_test.write_string_attribute(file_id, 'created_date', '2024-01-02T03:04:05.123456Z');
            H5G.create(file_id, 'activities', 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');

            gid = H5G.create(file_id, 'mystery_metadata', 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');
            malformed_load_test.write_string_attribute(gid, '_specification_name', 'totally_unknown_type');
            malformed_load_test.write_string_attribute(gid, '_descriptive_name', 'Mystery metadata');
            malformed_load_test.write_version_attribute(gid, [9 9 9]);

            space_id = H5S.create('H5S_SCALAR');
            str_type_id = H5T.copy('H5T_C_S1');
            H5T.set_size(str_type_id, 'H5T_VARIABLE');
            did = H5D.create(gid, 'original_type_name', str_type_id, space_id, 'H5P_DEFAULT');
            H5D.write(did, str_type_id, 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', 'totally_unknown_type');
            malformed_load_test.write_string_attribute(did, 'data_type', 'str');
            H5D.close(did);
            H5T.close(str_type_id);
            H5S.close(space_id);

            H5G.close(gid);
            H5F.close(file_id);

            loaded = escdf.load(outfile);
            metadata = loaded.get_metadata();
            testCase.verifyEqual(numel(metadata), 1);
            testCase.verifyEqual(metadata(1).get_type(), 'unknown');
        end

        function test_load_missing_descriptive_name_defaults_to_group_name(testCase)
            outfile = fullfile(testCase.temp_folder, 'missing_descriptive_name.h5');
            file_id = H5F.create(outfile, 'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');

            malformed_load_test.write_string_attribute(file_id, 'created_by', 'someone');
            malformed_load_test.write_string_attribute(file_id, 'created_date', '2024-01-02T03:04:05.123456Z');
            H5G.create(file_id, 'activities', 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');

            malformed_load_test.create_minimal_scalar_group(file_id, 'meta1', 'scalar', '');

            H5F.close(file_id);

            loaded = escdf.load(outfile);
            metadata = loaded.get_metadata('meta1');
            testCase.verifyEqual(metadata.get_descriptive_name(), 'meta1');
        end

        function test_load_malformed_version_still_loads(testCase)
            outfile = fullfile(testCase.temp_folder, 'malformed_version.h5');
            file_id = H5F.create(outfile, 'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');

            malformed_load_test.write_string_attribute(file_id, 'created_by', 'someone');
            malformed_load_test.write_string_attribute(file_id, 'created_date', '2024-01-02T03:04:05.123456Z');
            H5G.create(file_id, 'activities', 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');

            gid = H5G.create(file_id, 'meta1', 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');
            malformed_load_test.write_string_attribute(gid, '_specification_name', 'scalar');
            malformed_load_test.write_string_attribute(gid, '_descriptive_name', 'Scalar metadata');
            malformed_load_test.write_version_attribute(gid, [123 456]); % malformed

            value_space = H5S.create('H5S_SCALAR');
            value_did = H5D.create(gid, 'value', 'H5T_IEEE_F64LE', value_space, 'H5P_DEFAULT');
            H5D.write(value_did, 'H5T_IEEE_F64LE', 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', 2.0);
            malformed_load_test.write_string_attribute(value_did, 'data_type', 'f8');
            H5D.close(value_did);
            H5S.close(value_space);

            H5G.close(gid);
            H5F.close(file_id);

            loaded = escdf.load(outfile);
            metadata = loaded.get_metadata('meta1');
            testCase.verifyEqual(metadata.get_type(), 'scalar');
        end

        function test_load_missing_activities_group_errors(testCase)
            outfile = fullfile(testCase.temp_folder, 'missing_activities_group.h5');
            file_id = H5F.create(outfile, 'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');

            malformed_load_test.write_string_attribute(file_id, 'created_by', 'someone');
            malformed_load_test.write_string_attribute(file_id, 'created_date', '2024-01-02T03:04:05.123456Z');

            H5F.close(file_id);

            didError = false;
            try
                escdf.load(outfile);
            catch
                didError = true;
            end
            testCase.verifyTrue(didError);
        end
    end
end