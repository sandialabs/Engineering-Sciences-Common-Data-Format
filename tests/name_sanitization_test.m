classdef name_sanitization_test < matlab.unittest.TestCase

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

            name_sanitization_test.write_string_attribute(gid, '_specification_name', dataset_type);
            name_sanitization_test.write_string_attribute(gid, '_descriptive_name', descriptive_name);
            name_sanitization_test.write_version_attribute(gid, [0 1 0]);

            value_space = H5S.create('H5S_SCALAR');
            value_did = H5D.create(gid, 'value', 'H5T_IEEE_F64LE', value_space, 'H5P_DEFAULT');
            H5D.write(value_did, 'H5T_IEEE_F64LE', 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', 1.25);
            name_sanitization_test.write_string_attribute(value_did, 'data_type', 'f8');
            H5D.close(value_did);
            H5S.close(value_space);

            unit_space = H5S.create('H5S_SCALAR');
            str_type_id = H5T.copy('H5T_C_S1');
            H5T.set_size(str_type_id, 'H5T_VARIABLE');
            unit_did = H5D.create(gid, 'unit', str_type_id, unit_space, 'H5P_DEFAULT');
            H5D.write(unit_did, str_type_id, 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', 'g');
            name_sanitization_test.write_string_attribute(unit_did, 'data_type', 'str');
            H5D.close(unit_did);
            H5T.close(str_type_id);
            H5S.close(unit_space);

            H5G.close(gid);
        end
    end

    methods (Test)

        function test_is_valid_identifier(testCase)
            testCase.verifyTrue(escdf.is_valid_identifier('abc'));
            testCase.verifyTrue(escdf.is_valid_identifier('a1_b2'));
            testCase.verifyFalse(escdf.is_valid_identifier('1abc'));
            testCase.verifyFalse(escdf.is_valid_identifier('a-b'));
            testCase.verifyFalse(escdf.is_valid_identifier('a b'));
            testCase.verifyFalse(escdf.is_valid_identifier(''));
        end

        function test_make_valid_identifier_replaces_invalid_name(testCase)
            out = escdf.make_valid_identifier('1 bad-name', 'dataset_');
            testCase.verifyEqual(out, 'dataset_1_badname');
            testCase.verifyTrue(escdf.is_valid_identifier(out));
        end

        function test_make_valid_identifier_leaves_valid_name_unchanged(testCase)
            out = escdf.make_valid_identifier('valid_name', 'dataset_');
            testCase.verifyEqual(out, 'valid_name');
        end

        function test_dataset_replace_invalid_name(testCase)
            ds = escdf_dataset( ...
                '1 bad-name', ...
                'scalar', ...
                'Example dataset', ...
                true);

            testCase.verifyEqual(ds.get_name(), 'dataset_1_badname');
        end

        function test_dataset_invalid_name_raises_without_replacement(testCase)
            didError = false;
            try
                escdf_dataset( ...
                    '1 bad-name', ...
                    'scalar', ...
                    'Example dataset', ...
                    false);
            catch
                didError = true;
            end
            testCase.verifyTrue(didError);
        end

        function test_activity_replace_invalid_name(testCase)
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');

            activity = escdf_activity( ...
                '1 bad-name', ...
                'Example activity', ...
                when, ...
                [], ...
                {}, ...
                true);

            testCase.verifyEqual(activity.get_name(), 'activity_1_badname');
        end

        function test_activity_invalid_name_raises_without_replacement(testCase)
            when = datetime(2024,1,2,3,4,5,'TimeZone','UTC');

            didError = false;
            try
                escdf_activity( ...
                    '1 bad-name', ...
                    'Example activity', ...
                    when, ...
                    [], ...
                    {}, ...
                    false);
            catch
                didError = true;
            end
            testCase.verifyTrue(didError);
        end

        function test_load_invalid_activity_name_repairs_name(testCase)
            outfile = fullfile(testCase.temp_folder, 'invalid_activity_name.h5');
            file_id = H5F.create(outfile, 'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');

            name_sanitization_test.write_string_attribute(file_id, 'created_by', 'someone');
            name_sanitization_test.write_string_attribute(file_id, 'created_date', '2024-01-02T03:04:05.123456Z');

            activities_gid = H5G.create(file_id, 'activities', 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');
            act_gid = H5G.create(activities_gid, '1 bad-name', 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');

            name_sanitization_test.write_string_attribute(act_gid, 'activity_name', 'Example activity');
            name_sanitization_test.write_string_attribute(act_gid, 'activity_date', '2024-01-02T03:04:05.123456Z');

            % empty parameters dataset
            space_id = H5S.create_simple(1, 0, []);
            str_type_id = H5T.copy('H5T_C_S1');
            H5T.set_size(str_type_id, 'H5T_VARIABLE');
            did = H5D.create(act_gid, 'parameters', str_type_id, space_id, 'H5P_DEFAULT');
            name_sanitization_test.write_string_attribute(did, 'data_type', 'str');
            H5D.close(did);
            H5T.close(str_type_id);
            H5S.close(space_id);

            H5G.close(act_gid);
            H5G.close(activities_gid);
            H5F.close(file_id);

            loaded = escdf.load(outfile);
            activity = loaded.get_activity('activity_1_badname');

            testCase.verifyEqual(activity.get_name(), 'activity_1_badname');
            testCase.verifyEqual(activity.get_descriptive_name(), 'Example activity');
        end

        function test_load_invalid_metadata_name_repairs_name(testCase)
            outfile = fullfile(testCase.temp_folder, 'invalid_metadata_name.h5');
            file_id = H5F.create(outfile, 'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');

            name_sanitization_test.write_string_attribute(file_id, 'created_by', 'someone');
            name_sanitization_test.write_string_attribute(file_id, 'created_date', '2024-01-02T03:04:05.123456Z');

            H5G.create(file_id, 'activities', 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');

            name_sanitization_test.create_minimal_scalar_group( ...
                file_id, ...
                '1 bad-name', ...
                'scalar', ...
                'Bad metadata');

            H5F.close(file_id);

            loaded = escdf.load(outfile);
            metadata = loaded.get_metadata('dataset_1_badname');

            testCase.verifyEqual(metadata.get_name(), 'dataset_1_badname');
            testCase.verifyEqual(metadata.get_descriptive_name(), 'Bad metadata');
        end

        function test_load_invalid_metadata_link_repairs_name(testCase)
            outfile = fullfile(testCase.temp_folder, 'invalid_metadata_link.h5');
            file_id = H5F.create(outfile, 'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');

            name_sanitization_test.write_string_attribute(file_id, 'created_by', 'someone');
            name_sanitization_test.write_string_attribute(file_id, 'created_date', '2024-01-02T03:04:05.123456Z');

            % metadata with invalid name
            name_sanitization_test.create_minimal_scalar_group( ...
                file_id, ...
                '1 bad-meta', ...
                'scalar', ...
                'Bad metadata');

            % activity referencing invalid metadata name
            activities_gid = H5G.create(file_id, 'activities', 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');
            act_gid = H5G.create(activities_gid, 'act1', 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');

            name_sanitization_test.write_string_attribute(act_gid, 'activity_name', 'Example activity');
            name_sanitization_test.write_string_attribute(act_gid, 'activity_date', '2024-01-02T03:04:05.123456Z');

            % parameters dataset with one metadata link
            space_id = H5S.create_simple(1, 1, []);
            str_type_id = H5T.copy('H5T_C_S1');
            H5T.set_size(str_type_id, 'H5T_VARIABLE');
            did = H5D.create(act_gid, 'parameters', str_type_id, space_id, 'H5P_DEFAULT');
            H5D.write(did, str_type_id, 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', {'1 bad-meta'});
            name_sanitization_test.write_string_attribute(did, 'data_type', 'str');

            H5D.close(did);
            H5T.close(str_type_id);
            H5S.close(space_id);

            H5G.close(act_gid);
            H5G.close(activities_gid);
            H5F.close(file_id);

            loaded = escdf.load(outfile);
            activity = loaded.get_activity('act1');

            testCase.verifyEqual(activity.get_metadata_links(), {'dataset_1_badmeta'});

            metadata = loaded.get_metadata('dataset_1_badmeta');
            testCase.verifyEqual(metadata.get_name(), 'dataset_1_badmeta');
        end
    end
end