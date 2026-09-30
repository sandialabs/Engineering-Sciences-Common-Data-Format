classdef validation_edge_cases_test < matlab.unittest.TestCase
% VALIDATION_EDGE_CASES_TEST Edge-case tests for canonical dataset validation.
%
% This test class mirrors the semantic intent of the Python
% validation_edge_cases_test.py suite using temporary specification files
% and the MATLAB escdf_dataset validation path.

    properties
        temp_folder
        original_path
        source_folder
        temp_spec_folder

        choice_specification_file
        enum_specification_file
        regex_specification_file
        dims_specification_file
        ambiguous_choice_specification_file
        value_constraints_specification_file
        requires_specification_file
    end

    methods (TestMethodSetup)
        function setupEnvironment(testCase)
            current_file_folder = fileparts(mfilename('fullpath'));
            testCase.source_folder = fullfile(current_file_folder, '..', 'escdf');
            testCase.temp_folder = tempname;
            testCase.temp_spec_folder = fullfile(testCase.temp_folder, 'specifications');
            testCase.original_path = addpath(testCase.source_folder);
            mkdir(testCase.temp_folder);
            mkdir(testCase.temp_spec_folder);

            testCase.choice_specification_file = ...
                fullfile(testCase.temp_spec_folder, 'validation_choice_spec.txt');
            testCase.enum_specification_file = ...
                fullfile(testCase.temp_spec_folder, 'validation_enum_spec.txt');
            testCase.regex_specification_file = ...
                fullfile(testCase.temp_spec_folder, 'validation_regex_spec.txt');
            testCase.dims_specification_file = ...
                fullfile(testCase.temp_spec_folder, 'validation_dims_spec.txt');
            testCase.ambiguous_choice_specification_file = ...
                fullfile(testCase.temp_spec_folder, 'validation_ambiguous_choice_spec.txt');
            testCase.value_constraints_specification_file = ...
                fullfile(testCase.temp_spec_folder, 'validation_value_constraints_spec.txt');
            testCase.requires_specification_file = ...
                fullfile(testCase.temp_spec_folder, 'validation_requires_spec.txt');

            validation_edge_cases_test.write_choice_specification( ...
                testCase.choice_specification_file);
            validation_edge_cases_test.write_enum_specification( ...
                testCase.enum_specification_file);
            validation_edge_cases_test.write_regex_specification( ...
                testCase.regex_specification_file);
            validation_edge_cases_test.write_dims_specification( ...
                testCase.dims_specification_file);
            validation_edge_cases_test.write_ambiguous_choice_specification( ...
                testCase.ambiguous_choice_specification_file);
            validation_edge_cases_test.write_value_constraints_specification( ...
                testCase.value_constraints_specification_file);
            validation_edge_cases_test.write_requires_specification( ...
                testCase.requires_specification_file);

            escdf_dataset.reload_specification_cache();
            escdf_dataset.load_specification_directory(testCase.temp_spec_folder);
        end
    end

    methods (TestMethodTeardown)
        function teardownEnvironment(testCase)
            escdf_dataset.reload_specification_cache();

            if isfolder(testCase.temp_folder)
                rmdir(testCase.temp_folder, 's');
            end
            path(testCase.original_path);
        end
    end

    methods (Static)
        function write_choice_specification(file_path)
            fid = fopen(file_path, 'w');
            fprintf(fid, 'validation_choice_spec - v0.1.0\n');
            fprintf(fid, '--------------------------------\n');
            fprintf(fid, 'extends: activity_result\n');
            fprintf(fid, '\n');
            fprintf(fid, 'properties\n');
            fprintf(fid, '----------\n');
            fprintf(fid, 'a - i8 - scalar - or:choice:ab\n');
            fprintf(fid, 'b - i8 - scalar - or:choice:ab\n');
            fprintf(fid, 'a - i8 - scalar - or:choice:ac\n');
            fprintf(fid, 'c - i8 - scalar - or:choice:ac\n');
            fprintf(fid, 'd - i8 - scalar - or:choice:d_scalar\n');
            fprintf(fid, 'd - i8 - num_vals - or:choice:d_array\n');
            fclose(fid);
        end

        function write_enum_specification(file_path)
            fid = fopen(file_path, 'w');
            fprintf(fid, 'validation_enum_spec - v0.1.0\n');
            fprintf(fid, '------------------------------\n');
            fprintf(fid, 'extends: activity_result\n');
            fprintf(fid, '\n');
            fprintf(fid, 'properties\n');
            fprintf(fid, '----------\n');
            fprintf(fid, 'required_name - str - scalar\n');
            fprintf(fid, 'optional_name - str - scalar - optional\n');
            fprintf(fid, 'color - str - scalar - enum:colors\n');
            fprintf(fid, 'color_array - str - num_vals - enum:colors\n');
            fprintf(fid, '\n');
            fprintf(fid, 'enumerations\n');
            fprintf(fid, '------------\n');
            fprintf(fid, 'colors - red, green, blue\n');
            fclose(fid);
        end

        function write_regex_specification(file_path)
            fid = fopen(file_path, 'w');
            fprintf(fid, 'validation_regex_spec - v0.1.0\n');
            fprintf(fid, '-------------------------------\n');
            fprintf(fid, 'extends: activity_result\n');
            fprintf(fid, '\n');
            fprintf(fid, 'properties\n');
            fprintf(fid, '----------\n');
            fprintf(fid, 'channel - str - num_channels - regex:^\\d+(R?[XYZ]{1,2}[+-])?$\n');
            fclose(fid);
        end

        function write_dims_specification(file_path)
            fid = fopen(file_path, 'w');
            fprintf(fid, 'validation_dims_spec - v0.1.0\n');
            fprintf(fid, '------------------------------\n');
            fprintf(fid, 'extends: activity_result\n');
            fprintf(fid, '\n');
            fprintf(fid, 'properties\n');
            fprintf(fid, '----------\n');
            fprintf(fid, 'x - f8 - num_points\n');
            fprintf(fid, 'y - f8 - num_points\n');
            fprintf(fid, 'z - f8 - num_other_points - optional\n');
            fprintf(fid, 'm - f8 - num_rows,num_cols\n');
            fprintf(fid, 'n - f8 - num_rows,num_cols\n');
            fclose(fid);
        end

        function write_ambiguous_choice_specification(file_path)
            fid = fopen(file_path, 'w');
            fprintf(fid, 'validation_ambiguous_choice_spec - v0.1.0\n');
            fprintf(fid, '------------------------------------------\n');
            fprintf(fid, 'extends: activity_result\n');
            fprintf(fid, '\n');
            fprintf(fid, 'properties\n');
            fprintf(fid, '----------\n');
            fprintf(fid, 'same - i8 - scalar - or:ambig:first\n');
            fprintf(fid, 'same - i8 - scalar - or:ambig:second\n');
            fclose(fid);
        end

        function write_value_constraints_specification(file_path)
            fid = fopen(file_path, 'w');
            fprintf(fid, 'validation_value_constraints_spec - v0.1.0\n');
            fprintf(fid, '------------------------------------------\n');
            fprintf(fid, 'extends: activity_result\n');
            fprintf(fid, '\n');
            fprintf(fid, 'properties\n');
            fprintf(fid, '----------\n');
            fprintf(fid, 'positive_scalar - f8 - scalar - positive\n');
            fprintf(fid, 'nonnegative_vector - f8 - num_vals - nonnegative\n');
            fprintf(fid, 'finite_vector - f8 - num_vals - finite\n');
            fprintf(fid, 'increasing_vector - f8 - num_vals - increasing\n');
            fprintf(fid, 'strictly_increasing_vector - f8 - num_vals - strictly_increasing\n');
            fprintf(fid, 'unique_ids - u8 - num_ids - unique\n');
            fprintf(fid, 'nonempty_name - str - scalar - nonempty\n');
            fclose(fid);
        end

        function write_requires_specification(file_path)
            fid = fopen(file_path, 'w');
            fprintf(fid, 'validation_requires_spec - v0.1.0\n');
            fprintf(fid, '---------------------------------\n');
            fprintf(fid, 'extends: parameter_set\n');
            fprintf(fid, '\n');
            fprintf(fid, 'properties\n');
            fprintf(fid, '----------\n');
            fprintf(fid, 'attachments - bytes - num_attachments - optional,requires:attachment_names\n');
            fprintf(fid, 'attachment_names - str - num_attachments - optional,requires:attachments\n');
            fclose(fid);
        end

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

        function write_scalar_string_dataset(group_id, dataset_name, value)
            space_id = H5S.create('H5S_SCALAR');
            str_type_id = H5T.copy('H5T_C_S1');
            H5T.set_size(str_type_id, 'H5T_VARIABLE');
            did = H5D.create(group_id, dataset_name, str_type_id, space_id, 'H5P_DEFAULT');
            H5D.write(did, str_type_id, 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', value);
            validation_edge_cases_test.write_string_attribute(did, 'data_type', 'str');
            H5D.close(did);
            H5T.close(str_type_id);
            H5S.close(space_id);
        end

    end

    methods (Test)
        function test_missing_required_property_fails(testCase)
            ds = escdf_dataset('d1', 'validation_enum_spec');
            ds.color = {'red'};
            ds.color_array = {'red'; 'green'};
            testCase.verifyFalse(ds.validate());
        end

        function test_optional_property_can_be_omitted(testCase)
            ds = escdf_dataset('d1', 'validation_enum_spec');
            ds.required_name = {'example'};
            ds.color = {'red'};
            ds.color_array = {'red'; 'green'};
            testCase.verifyTrue(isempty(ds.optional_name));
            testCase.verifyTrue(ds.validate());
        end

        function test_enum_scalar_invalid_fails(testCase)
            ds = escdf_dataset('d1', 'validation_enum_spec');
            ds.required_name = {'example'};
            ds.color = {'yellow'};
            ds.color_array = {'red'; 'green'};
            testCase.verifyFalse(ds.validate());
        end

        function test_enum_array_invalid_fails(testCase)
            ds = escdf_dataset('d1', 'validation_enum_spec');
            ds.required_name = {'example'};
            ds.color = {'red'};
            ds.color_array = {'red'; 'orange'};
            testCase.verifyFalse(ds.validate());
        end

        function test_enum_values_valid_pass(testCase)
            ds = escdf_dataset('d1', 'validation_enum_spec');
            ds.required_name = {'example'};
            ds.color = {'blue'};
            ds.color_array = {'red'; 'green'; 'blue'};
            testCase.verifyTrue(ds.validate());
        end

        function test_regex_valid_passes(testCase)
            ds = escdf_dataset('d1', 'validation_regex_spec');
            ds.channel = {'1X+'; '25RY-'; '100'; '32ZX-'};
            testCase.verifyTrue(ds.validate());
        end

        function test_regex_invalid_fails(testCase)
            ds = escdf_dataset('d1', 'validation_regex_spec');
            ds.channel = {'1X+'; 'BAD_CHANNEL'};
            testCase.verifyFalse(ds.validate());
        end

        function test_variable_dimension_consistency_passes(testCase)
            ds = escdf_dataset('d1', 'validation_dims_spec');
            ds.x = [1.0; 2.0; 3.0];
            ds.y = [4.0; 5.0; 6.0];
            ds.m = [1.0 2.0; 3.0 4.0];
            ds.n = [5.0 6.0; 7.0 8.0];
            testCase.verifyTrue(ds.validate());
        end

        function test_variable_dimension_mismatch_fails(testCase)
            ds = escdf_dataset('d1', 'validation_dims_spec');
            ds.x = [1.0; 2.0; 3.0];
            ds.y = [4.0; 5.0];
            ds.m = [1.0 2.0; 3.0 4.0];
            ds.n = [5.0 6.0; 7.0 8.0];
            testCase.verifyFalse(ds.validate());
        end

        function test_matrix_dimension_mismatch_fails(testCase)
            ds = escdf_dataset('d1', 'validation_dims_spec');
            ds.x = [1.0; 2.0];
            ds.y = [3.0; 4.0];
            ds.m = [1.0 2.0; 3.0 4.0];
            ds.n = [5.0 6.0 7.0; 8.0 9.0 10.0];
            testCase.verifyFalse(ds.validate());
        end

        function test_choice_ab_valid(testCase)
            ds = escdf_dataset('d1', 'validation_choice_spec');
            ds.a = int64(1);
            ds.b = int64(2);
            testCase.verifyTrue(ds.validate());
        end

        function test_choice_ac_valid(testCase)
            ds = escdf_dataset('d1', 'validation_choice_spec');
            ds.a = int64(1);
            ds.c = int64(3);
            testCase.verifyTrue(ds.validate());
        end

        function test_choice_missing_pair_fails(testCase)
            ds = escdf_dataset('d1', 'validation_choice_spec');
            ds.a = int64(1);
            testCase.verifyFalse(ds.validate());
        end

        function test_choice_d_scalar_valid(testCase)
            ds = escdf_dataset('d1', 'validation_choice_spec');
            ds.d = int64(1);
            testCase.verifyTrue(ds.validate());
        end

        function test_choice_d_array_valid(testCase)
            ds = escdf_dataset('d1', 'validation_choice_spec');
            ds.d = int64([1; 2; 3]);
            testCase.verifyTrue(ds.validate());
        end

        function test_explicit_ambiguous_choice_reports_invalid(testCase)
            ds = escdf_dataset('d1', 'validation_ambiguous_choice_spec');
            ds.same = int64(1);
            testCase.verifyFalse(ds.validate());
        end

        function test_loaded_extra_property_invalidates_dataset(testCase)
        % Verify that a dataset loaded with an unknown extra property is
        % marked modified and therefore fails validation.

            outfile = fullfile(testCase.temp_folder, 'modified_dataset.h5');
            file_id = H5F.create(outfile, 'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');

            % Root attributes
            validation_edge_cases_test.write_string_attribute(file_id, 'created_by', 'someone');
            validation_edge_cases_test.write_string_attribute(file_id, 'created_date', '2024-01-02T03:04:05.123456Z');

            % Required activities group
            H5G.create(file_id, 'activities', 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');

            % Dataset group matching validation_enum_spec
            gid = H5G.create(file_id, 'meta1', 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');
            validation_edge_cases_test.write_string_attribute(gid, '_specification_name', 'validation_enum_spec');
            validation_edge_cases_test.write_string_attribute(gid, '_descriptive_name', 'Validation metadata');
            validation_edge_cases_test.write_version_attribute(gid, [0 1 0]);

            % required_name
            space_id = H5S.create('H5S_SCALAR');
            str_type_id = H5T.copy('H5T_C_S1');
            H5T.set_size(str_type_id, 'H5T_VARIABLE');
            did = H5D.create(gid, 'required_name', str_type_id, space_id, 'H5P_DEFAULT');
            H5D.write(did, str_type_id, 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', 'example');
            validation_edge_cases_test.write_string_attribute(did, 'data_type', 'str');
            H5D.close(did);
            H5T.close(str_type_id);
            H5S.close(space_id);

            % color
            space_id = H5S.create('H5S_SCALAR');
            str_type_id = H5T.copy('H5T_C_S1');
            H5T.set_size(str_type_id, 'H5T_VARIABLE');
            did = H5D.create(gid, 'color', str_type_id, space_id, 'H5P_DEFAULT');
            H5D.write(did, str_type_id, 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', 'red');
            validation_edge_cases_test.write_string_attribute(did, 'data_type', 'str');
            H5D.close(did);
            H5T.close(str_type_id);
            H5S.close(space_id);

            % color_array
            space_id = H5S.create_simple(1, 2, []);
            str_type_id = H5T.copy('H5T_C_S1');
            H5T.set_size(str_type_id, 'H5T_VARIABLE');
            did = H5D.create(gid, 'color_array', str_type_id, space_id, 'H5P_DEFAULT');
            H5D.write(did, str_type_id, 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', {'red', 'green'});
            validation_edge_cases_test.write_string_attribute(did, 'data_type', 'str');
            H5D.close(did);
            H5T.close(str_type_id);
            H5S.close(space_id);

            % Unknown extra property
            extra_space = H5S.create_simple(1, 3, []);
            extra_did = H5D.create(gid, 'unexpected_field', 'H5T_IEEE_F64LE', extra_space, 'H5P_DEFAULT');
            H5D.write(extra_did, 'H5T_IEEE_F64LE', 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', [1.0 2.0 3.0]);
            validation_edge_cases_test.write_string_attribute(extra_did, 'data_type', 'f8');
            H5D.close(extra_did);
            H5S.close(extra_space);

            H5G.close(gid);
            H5F.close(file_id);

            loaded = escdf.load(outfile);
            md = loaded.get_metadata('meta1');

            testCase.verifyTrue(md.get_has_modified_properties());
            testCase.verifyFalse(md.validate());
        end

        function test_wrong_shape_rejected_by_assignment_or_validation(testCase)
            ds = escdf_dataset('d1', 'validation_dims_spec');
            ds.x = [1.0; 2.0; 3.0];
            ds.m = [1.0 2.0; 3.0 4.0];
            ds.n = [5.0 6.0; 7.0 8.0];

            didError = false;
            try
                ds.y = [4.0 5.0 6.0];
            catch
                didError = true;
            end

            if didError
                testCase.verifyTrue(didError);
            else
                testCase.verifyFalse(ds.validate());
            end
        end

        function test_positive_scalar_valid(testCase)
            ds = escdf_dataset('d1', 'validation_value_constraints_spec');
            ds.positive_scalar = 1.25;
            ds.nonnegative_vector = [0.0; 1.0; 2.0];
            ds.finite_vector = [1.0; 2.0; 3.0];
            ds.increasing_vector = [1.0; 1.0; 2.0];
            ds.strictly_increasing_vector = [1.0; 2.0; 3.0];
            ds.unique_ids = uint64([1; 2; 3]);
            ds.nonempty_name = {'example'};
            testCase.verifyTrue(ds.validate());
        end

        function test_positive_scalar_invalid_fails(testCase)
            ds = escdf_dataset('d1', 'validation_value_constraints_spec');
            ds.positive_scalar = 0.0;
            ds.nonnegative_vector = [0.0; 1.0; 2.0];
            ds.finite_vector = [1.0; 2.0; 3.0];
            ds.increasing_vector = [1.0; 1.0; 2.0];
            ds.strictly_increasing_vector = [1.0; 2.0; 3.0];
            ds.unique_ids = uint64([1; 2; 3]);
            ds.nonempty_name = {'example'};
            testCase.verifyFalse(ds.validate());
        end

        function test_nonnegative_vector_invalid_fails(testCase)
            ds = escdf_dataset('d1', 'validation_value_constraints_spec');
            ds.positive_scalar = 1.0;
            ds.nonnegative_vector = [0.0; -1.0; 2.0];
            ds.finite_vector = [1.0; 2.0; 3.0];
            ds.increasing_vector = [1.0; 1.0; 2.0];
            ds.strictly_increasing_vector = [1.0; 2.0; 3.0];
            ds.unique_ids = uint64([1; 2; 3]);
            ds.nonempty_name = {'example'};
            testCase.verifyFalse(ds.validate());
        end

        function test_finite_vector_invalid_fails(testCase)
            ds = escdf_dataset('d1', 'validation_value_constraints_spec');
            ds.positive_scalar = 1.0;
            ds.nonnegative_vector = [0.0; 1.0; 2.0];
            ds.finite_vector = [1.0; Inf; 3.0];
            ds.increasing_vector = [1.0; 1.0; 2.0];
            ds.strictly_increasing_vector = [1.0; 2.0; 3.0];
            ds.unique_ids = uint64([1; 2; 3]);
            ds.nonempty_name = {'example'};
            testCase.verifyFalse(ds.validate());
        end

        function test_increasing_vector_invalid_fails(testCase)
            ds = escdf_dataset('d1', 'validation_value_constraints_spec');
            ds.positive_scalar = 1.0;
            ds.nonnegative_vector = [0.0; 1.0; 2.0];
            ds.finite_vector = [1.0; 2.0; 3.0];
            ds.increasing_vector = [1.0; 0.5; 2.0];
            ds.strictly_increasing_vector = [1.0; 2.0; 3.0];
            ds.unique_ids = uint64([1; 2; 3]);
            ds.nonempty_name = {'example'};
            testCase.verifyFalse(ds.validate());
        end

        function test_strictly_increasing_vector_invalid_fails(testCase)
            ds = escdf_dataset('d1', 'validation_value_constraints_spec');
            ds.positive_scalar = 1.0;
            ds.nonnegative_vector = [0.0; 1.0; 2.0];
            ds.finite_vector = [1.0; 2.0; 3.0];
            ds.increasing_vector = [1.0; 1.0; 2.0];
            ds.strictly_increasing_vector = [1.0; 1.0; 2.0];
            ds.unique_ids = uint64([1; 2; 3]);
            ds.nonempty_name = {'example'};
            testCase.verifyFalse(ds.validate());
        end

        function test_unique_ids_invalid_fails(testCase)
            ds = escdf_dataset('d1', 'validation_value_constraints_spec');
            ds.positive_scalar = 1.0;
            ds.nonnegative_vector = [0.0; 1.0; 2.0];
            ds.finite_vector = [1.0; 2.0; 3.0];
            ds.increasing_vector = [1.0; 1.0; 2.0];
            ds.strictly_increasing_vector = [1.0; 2.0; 3.0];
            ds.unique_ids = uint64([1; 2; 2]);
            ds.nonempty_name = {'example'};
            testCase.verifyFalse(ds.validate());
        end

        function test_nonempty_name_invalid_fails(testCase)
            ds = escdf_dataset('d1', 'validation_value_constraints_spec');
            ds.positive_scalar = 1.0;
            ds.nonnegative_vector = [0.0; 1.0; 2.0];
            ds.finite_vector = [1.0; 2.0; 3.0];
            ds.increasing_vector = [1.0; 1.0; 2.0];
            ds.strictly_increasing_vector = [1.0; 2.0; 3.0];
            ds.unique_ids = uint64([1; 2; 3]);
            ds.nonempty_name = {''};
            testCase.verifyFalse(ds.validate());
        end

        function test_value_constraint_failure_appears_in_report(testCase)
            ds = escdf_dataset('d1', 'validation_value_constraints_spec');
            ds.positive_scalar = -1.0;
            ds.nonnegative_vector = [0.0; 1.0; 2.0];
            ds.finite_vector = [1.0; 2.0; 3.0];
            ds.increasing_vector = [1.0; 1.0; 2.0];
            ds.strictly_increasing_vector = [1.0; 2.0; 3.0];
            ds.unique_ids = uint64([1; 2; 3]);
            ds.nonempty_name = {'example'};

            report = ds.validate(true, true);
            testCase.verifyClass(report, 'ValidationReport');
            testCase.verifyFalse(report.is_valid);
            testCase.verifyGreaterThan(numel(report.invalid_value_constraints), 0);
        end

        function test_requires_constraint_neither_present_is_valid(testCase)
            ds = escdf_dataset('d1', 'validation_requires_spec');
            testCase.verifyTrue(ds.validate());
        end

        function test_requires_constraint_both_present_is_valid(testCase)
            ds = escdf_dataset('d1', 'validation_requires_spec');
            ds.attachment_names = {'a.bin'; 'b.bin'};
            ds.attachments = {
                uint8([1; 2; 3])
                uint8([4; 5])
            };
            testCase.verifyTrue(ds.validate());
        end

        function test_requires_constraint_missing_attachment_names_fails(testCase)
            ds = escdf_dataset('d1', 'validation_requires_spec');
            ds.attachments = {
                uint8([1; 2; 3])
            };
            testCase.verifyFalse(ds.validate());
        end

        function test_requires_constraint_missing_attachments_fails(testCase)
            ds = escdf_dataset('d1', 'validation_requires_spec');
            ds.attachment_names = {'a.bin'};
            testCase.verifyFalse(ds.validate());
        end

        function test_requires_constraint_failure_appears_in_report(testCase)
            ds = escdf_dataset('d1', 'validation_requires_spec');
            ds.attachment_names = {'a.bin'};

            report = ds.validate(true, true);
            testCase.verifyClass(report, 'ValidationReport');
            testCase.verifyFalse(report.is_valid);
            testCase.verifyGreaterThan(numel(report.constraint_failures), 0);
        end
    end
end