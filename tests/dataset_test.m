classdef dataset_test < matlab.unittest.TestCase
    properties
        temp_folder;
        file_id;
        original_path;
        source_folder;
        test_specification_file;
        test_property_names;
        test_property_values;
        choice_specification_file;
        choice_property_names;
        choice_property_values;
        enum_specification_file;
        enum_property_names;
        enum_property_values;
        table_specification_file;
    end

    methods (TestMethodSetup)
        function createHDF5File(testCase)
            current_file_folder = fileparts(mfilename('fullpath'));
            testCase.source_folder = fullfile(current_file_folder, '..', 'escdf');
            testCase.temp_folder = tempname;
            testCase.original_path = addpath(testCase.source_folder);
            mkdir(testCase.temp_folder);
            testCase.file_id = H5F.create(fullfile(testCase.temp_folder,'escdf_dataset_test.h5'), 'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');
            testCase.test_specification_file = fullfile(testCase.source_folder,'specifications','unittesting_specification.txt');
            testCase.choice_specification_file = fullfile(testCase.source_folder,'specifications','choicetesting_specification.txt');
            testCase.enum_specification_file = fullfile(testCase.source_folder,'specifications','enumtesting_specification.txt');
            testCase.table_specification_file = fullfile(testCase.source_folder,'specifications','tabletesting_specification.txt');
            data_type = {...
                'u1','u2','u4','u8',...
                'i1','i2','i4','i8',...
                'f4','f8',...
                'c8','c16', ...
                'str','bytes'
                };
            data_size = {...
                [],...
                [8],...
                [9,6],...
                [12,8,10]...
                };
            ragged = {...
                true,...
                false...
                };
            % Create a specification file that covers all data types
            fid = fopen(testCase.test_specification_file,'w');
            fprintf(fid,'unittesting_specification - v0.1.0\n-------------------------\nextends: activity_result\n\nproperties\n----------\n');
            testCase.test_property_names = {};
            testCase.test_property_values = {};
            for idt = 1:length(data_type)
                dt = data_type{idt};
                for ids = 1:length(data_size)
                    ds = data_size{ids};
                    ndim = length(ds);
                    ds_name = sprintf('%g,',ds);
                    for irg = 1:length(ragged)
                        rg = ragged{irg};
                        if rg && strcmp(dt,'str')
                            continue
                        elseif rg && strcmp(dt,'bytes')
                            continue
                        elseif rg && strcmp(dt,'c8')
                            continue
                        elseif rg && strcmp(dt,'c16')
                            continue
                        end
                        name = [dt,sprintf('_ndim_%d',ndim)];
                        if rg
                            name = [name,'_ragged'];
                        end
                        fprintf(fid,'%s - %s',name, dt);
                        if isempty(ds_name(1:end-1))
                            if rg
                                fprintf(fid,' - scalar');
                            end
                        else
                            fprintf(fid,' - %s',ds_name(1:end-1));
                        end
                        if rg
                            fprintf(fid,' - variable_length\n');
                        else
                            fprintf(fid,'\n');
                        end
                        testCase.test_property_names{end+1} = name;
                        testCase.test_property_values{end+1} = {dt,ds,rg};
                    end
                end
            end
            fclose(fid);
            % Create a specification file that covers choices
            fid = fopen(testCase.choice_specification_file,'w');
            fprintf(fid,'choicetesting_specification - v0.1.0\n--------------------------\nextends: activity_result\n\nproperties\n----------\n');
            fprintf(fid,'a - i8 - scalar - or:choicetest:ab_scalar\n');
            fprintf(fid,'b - i8 - scalar - or:choicetest:ab_scalar\n');
            fprintf(fid,'a - i8 - scalar - or:choicetest:ac_scalar\n');
            fprintf(fid,'c - i8 - scalar - or:choicetest:ac_scalar\n');
            fprintf(fid,'d - i8 - scalar - or:choicetest:d_scalar\n');
            fprintf(fid,'d - i8 - size_a - or:choicetest:d_array\n');
            fprintf(fid,'e - f8 - scalar - or:choicetest:e_real\n');
            fprintf(fid,'e - c16 - scalar - or:choicetest:e_complex\n');
            fclose(fid);
            % Create a specification file that covers enumerations
            fid = fopen(testCase.enum_specification_file,'w');
            fprintf(fid,'enumtesting_specification - v0.1.0\n');
            fprintf(fid,'-------------------------\n');
            fprintf(fid,'extends: activity_result\n');
            fprintf(fid,'\n');
            fprintf(fid,'properties\n');
            fprintf(fid,'----------\n');
            fprintf(fid,'enum_scalar - str - scalar - enum:enum1\n');
            fprintf(fid,'enum_one_dim - str - num_vals - enum:enum2\n');
            fprintf(fid,'enum_two_dim - str - num_rows,num_cols - enum:enum2\n');
            fprintf(fid,'enum_three_dim - str - num_rows,num_cols,3 - enum:enum3\n');
            fprintf(fid,'enum_optional - str - scalar - optional,enum:enum1\n');
            fprintf(fid,'no_enum - str - scalar\n');
            fprintf(fid,'\n');
            fprintf(fid,'enumerations\n');
            fprintf(fid,'------------\n');
            fprintf(fid,'enum1 - red,orange,yellow,green,blue,violet\n');
            fprintf(fid,'enum2 - one, two, three, four,\n');
            fprintf(fid,'enum3 - do, re, mi, fa, sol, la, ti, do\n');
            fclose(fid);
            fid = fopen(testCase.table_specification_file,'w');
            fprintf(fid,'tabletesting_specification - v0.1.0\n');
            fprintf(fid,'---------------------------\n');
            fprintf(fid,'extends: activity_result\n');
            fprintf(fid,'\n');
            fprintf(fid,'properties\n');
            fprintf(fid,'----------\n');
            fprintf(fid,'vec - f8 - num_points\n');
            fprintf(fid,'mat - f8 - num_rows,num_cols\n');
            fprintf(fid,'cube - f8 - num_layers,num_rows,num_cols\n');
            fprintf(fid,'labels - str - num_rows\n');
            fclose(fid);
            % Clear cached specification state so the temporary
            % specification files created for this test are re-read.
            escdf_dataset.reload_specification_cache();
        end
    end

    methods (TestMethodTeardown)
        function deleteStoredData(testCase)
            H5F.close(testCase.file_id);
            rmdir(testCase.temp_folder,'s');
            path(testCase.original_path);
            delete(testCase.test_specification_file);
            delete(testCase.choice_specification_file);
            delete(testCase.enum_specification_file);
            delete(testCase.table_specification_file);
            escdf_dataset.reload_specification_cache();
        end
    end

    methods (Test)
        function testChoices(testCase)
        % Verify that valid non-ambiguous choice branches are accepted and
        % incomplete branches are rejected.
            test_dataset = escdf_dataset('choice_dataset','choicetesting_specification');
            test_dataset.a = 1;
            testCase.verifyFalse(test_dataset.validate());
            test_dataset.b = 1;
            testCase.verifyTrue(test_dataset.validate());

            test_dataset = escdf_dataset('choice_dataset','choicetesting_specification');
            test_dataset.a = 1;
            testCase.verifyFalse(test_dataset.validate());
            test_dataset.c = 1;
            testCase.verifyTrue(test_dataset.validate());

            test_dataset = escdf_dataset('choice_dataset','choicetesting_specification');
            test_dataset.d = 1;
            testCase.verifyTrue(test_dataset.validate());
            test_dataset.d = [1;1];
            testCase.verifyTrue(test_dataset.validate());

            test_dataset = escdf_dataset('choice_dataset','choicetesting_specification');
            test_dataset.e = 1.0;
            testCase.verifyTrue(test_dataset.validate());
            test_dataset.e = 1+1j;
            testCase.verifyTrue(test_dataset.validate());
        end

        function testChoicesReportsAmbiguousChoiceAsInvalid(testCase)
        % Verify that a dataset matching multiple valid choice branches is
        % reported as invalid rather than raising an exception.
            test_dataset = escdf_dataset('choice_dataset','choicetesting_specification');
            test_dataset.e = 1+1j;
            test_dataset.d = 1;

            testCase.verifyFalse(test_dataset.validate());
        end

        function testEnums(testCase)
            test_dataset = escdf_dataset('enum_dataset','enumtesting_specification');
            test_dataset.enum_scalar = {'red'};
            test_dataset.enum_one_dim = {'one','three','three','one'}.';
            test_dataset.enum_two_dim = {'one','three';'two','four';'one','one'};
            test_dataset.enum_three_dim = repmat({'do','re';'mi','fa';'sol','la'},[1,1,3]);
            test_dataset.no_enum = {'hello'};
            testCase.verifyTrue(test_dataset.validate());
            test_dataset.enum_scalar = {'re'};
            testCase.verifyFalse(test_dataset.validate());
            test_dataset.enum_scalar = {'red'};
            test_dataset.enum_three_dim = repmat({'do','ree';'mi','fa';'soo','la'},[1,1,3]);
            testCase.verifyFalse(test_dataset.validate());
        end

        function testStorageAndRecall(testCase)
            % Create the dataset
            dataset_name = 'test_dataset';
            dataset_type = 'unittesting_specification';
            dataset_descriptive_name = 'A dataset to test out the ability to read and write different formats.';
            test_dataset = escdf_dataset(dataset_name,dataset_type,dataset_descriptive_name);
            % Verify that the items are set correctly
            testCase.verifyEqual(test_dataset.get_name(),dataset_name);
            testCase.verifyEqual(test_dataset.get_descriptive_name(),dataset_descriptive_name);
            testCase.verifyEqual(test_dataset.get_type(),dataset_type);
            % Now we'll loop through each type and assign it to a dataset
            stored_data = {};
            for j = 1:length(testCase.test_property_names)
                prop_name = testCase.test_property_names{j};
                prop_data = testCase.test_property_values{j};
                data_type = prop_data{1};
                data_size = prop_data{2};
                ragged = prop_data{3};
                stride = 1;
                strides = arrayfun(@(sz) 1:stride:sz,data_size,'UniformOutput',false);
                stride_sizes = cellfun(@(s) length(s), strides, 'UniformOutput',false);
                if isempty(stride_sizes)
                    stride_sizes = {1,1};
                elseif length(stride_sizes) == 1
                    stride_sizes{end+1} = 1;
                end
                MAX_RAGGED_LENGTH = 50;
                switch data_type
                    case 'u1'
                        fn = @uint8;
                        minval = 0;
                        maxval = 2^8-1;
                        if ragged
                            ragged_array = cell(prod([stride_sizes{:}]),1);
                            for i = 1:length(ragged_array)
                                ragged_data = fn(randi([minval,maxval],[randi([1 , MAX_RAGGED_LENGTH]), 1]));
                                ragged_array{i,1} = ragged_data;
                            end
                            data = reshape(ragged_array,[stride_sizes{:}]);
                        else
                            data = fn(randi([minval,maxval],stride_sizes{:}));
                        end
                    case 'u2'
                        fn = @uint16;
                        minval = 0;
                        maxval = 2^16-1;
                        if ragged
                            ragged_array = cell(prod([stride_sizes{:}]),1);
                            for i = 1:length(ragged_array)
                                ragged_data = fn(randi([minval,maxval],[randi([1 , MAX_RAGGED_LENGTH]), 1]));
                                ragged_array{i,1} = ragged_data;
                            end
                            data = reshape(ragged_array,[stride_sizes{:}]);
                        else
                            data = fn(randi([minval,maxval],stride_sizes{:}));
                        end
                    case 'u4'
                        fn = @uint32;
                        minval = 0;
                        maxval = 2^32-1;
                        if ragged
                            ragged_array = cell(prod([stride_sizes{:}]),1);
                            for i = 1:length(ragged_array)
                                ragged_data = fn(randi([minval,maxval],[randi([1 , MAX_RAGGED_LENGTH]), 1]));
                                ragged_array{i,1} = ragged_data;
                            end
                            data = reshape(ragged_array,[stride_sizes{:}]);
                        else
                            data = fn(randi([minval,maxval],stride_sizes{:}));
                        end
                    case 'u8'
                        fn = @uint64;
                        minval = 0;
                        maxval = 2^53-2;
                        if ragged
                            ragged_array = cell(prod([stride_sizes{:}]),1);
                            for i = 1:length(ragged_array)
                                ragged_data = fn(randi([minval,maxval],[randi([1 , MAX_RAGGED_LENGTH]), 1]));
                                ragged_array{i,1} = ragged_data;
                            end
                            data = reshape(ragged_array,[stride_sizes{:}]);
                        else
                            data = fn(randi([minval,maxval],stride_sizes{:}));
                        end
                    case 'i1'
                        fn = @int8;
                        n = 8;
                        minval = -2^(n-1);
                        maxval = 2^(n-1)-1;
                        if ragged
                            ragged_array = cell(prod([stride_sizes{:}]),1);
                            for i = 1:length(ragged_array)
                                ragged_data = fn(randi([minval,maxval],[randi([1 , MAX_RAGGED_LENGTH]), 1]));
                                ragged_array{i,1} = ragged_data;
                            end
                            data = reshape(ragged_array,[stride_sizes{:}]);
                        else
                            data = fn(randi([minval,maxval],stride_sizes{:}));
                        end
                    case 'i2'
                        fn = @int16;
                        n = 16;
                        minval = -2^(n-1);
                        maxval = 2^(n-1)-1;
                        if ragged
                            ragged_array = cell(prod([stride_sizes{:}]),1);
                            for i = 1:length(ragged_array)
                                ragged_data = fn(randi([minval,maxval],[randi([1 , MAX_RAGGED_LENGTH]), 1]));
                                ragged_array{i,1} = ragged_data;
                            end
                            data = reshape(ragged_array,[stride_sizes{:}]);
                        else
                            data = fn(randi([minval,maxval],stride_sizes{:}));
                        end
                    case 'i4'
                        fn = @int32;
                        n = 32;
                        minval = -2^(n-1);
                        maxval = 2^(n-1)-1;
                        if ragged
                            ragged_array = cell(prod([stride_sizes{:}]),1);
                            for i = 1:length(ragged_array)
                                ragged_data = fn(randi([minval,maxval],[randi([1 , MAX_RAGGED_LENGTH]), 1]));
                                ragged_array{i,1} = ragged_data;
                            end
                            data = reshape(ragged_array,[stride_sizes{:}]);
                        else
                            data = fn(randi([minval,maxval],stride_sizes{:}));
                        end
                    case 'i8'
                        fn = @int64;
                        n = 53;
                        minval = -2^(n-1);
                        maxval = 2^(n-1)-2;
                        if ragged
                            ragged_array = cell(prod([stride_sizes{:}]),1);
                            for i = 1:length(ragged_array)
                                ragged_data = fn(randi([minval,maxval],[randi([1 , MAX_RAGGED_LENGTH]), 1]));
                                ragged_array{i,1} = ragged_data;
                            end
                            data = reshape(ragged_array,[stride_sizes{:}]);
                        else
                            data = fn(randi([minval,maxval],stride_sizes{:}));
                        end
                    case 'f4'
                        if ragged
                            ragged_array = cell(prod([stride_sizes{:}]),1);
                            for i = 1:length(ragged_array)
                                ragged_data = single(randn([randi([1 , MAX_RAGGED_LENGTH]), 1]));
                                ragged_array{i,1} = ragged_data;
                            end
                            data = reshape(ragged_array,[stride_sizes{:}]);
                        else
                            data = single(randn([stride_sizes{:}]));
                        end
                    case 'f8'
                        if ragged
                            ragged_array = cell(prod([stride_sizes{:}]),1);
                            for i = 1:length(ragged_array)
                                ragged_data = double(randn([randi([1 , MAX_RAGGED_LENGTH]), 1]));
                                ragged_array{i,1} = ragged_data;
                            end
                            data = reshape(ragged_array,[stride_sizes{:}]);
                        else
                            data = double(randn([stride_sizes{:}]));
                        end
                    case 'c8'
                        if ragged
                            ragged_array = cell(prod([stride_sizes{:}]),1);
                            for i = 1:length(ragged_array)
                                len = randi([1 , MAX_RAGGED_LENGTH]);
                                ragged_data = single(randn([len, 1]))+1j*single(randn([len, 1]));
                                ragged_array{i,1} = ragged_data;
                            end
                            data = reshape(ragged_array,[stride_sizes{:}]);
                        else
                            data = single(randn([stride_sizes{:}])) + 1j*single(randn([stride_sizes{:}]));
                        end
                    case 'c16'
                        if ragged
                            ragged_array = cell(prod([stride_sizes{:}]),1);
                            for i = 1:length(ragged_array)
                                len = randi([1 , MAX_RAGGED_LENGTH]);
                                ragged_data = double(randn([len, 1]))+1j*double(randn([len, 1]));
                                ragged_array{i,1} = ragged_data;
                            end
                            data = reshape(ragged_array,[stride_sizes{:}]);
                        else
                            data = double(randn([stride_sizes{:}])) + 1j*double(randn([stride_sizes{:}]));
                        end
                    case 'str'
                        cellstr = cell(prod([stride_sizes{:}]),1);
                        symbols = ['a':'z' 'A':'Z' '0':'9'];
                        for i = 1:length(cellstr)
                            nums = randi(numel(symbols),[1 randi([1,MAX_RAGGED_LENGTH])]);
                            st = symbols(nums);
                            cellstr{i,1} = st;
                        end
                        data = reshape(cellstr,[stride_sizes{:}]);
                    case 'bytes'
                        cellbytes = cell(prod([stride_sizes{:}]),1);
                        fn = @uint8;
                        minval = 0;
                        maxval = 2^8-1;
                        for i = 1:length(cellbytes)
                            nums = fn(randi([minval,maxval],[randi([1 , MAX_RAGGED_LENGTH]), 1]));
                            cellbytes{i,1} = nums;
                        end
                        data = reshape(cellbytes,[stride_sizes{:}]);
                end
                % Assign the data to the dataset
                stored_data{end+1} = data;
                test_dataset.(prop_name) = data;
            end
            testCase.verifyTrue(test_dataset.validate());
            % Now read the data back to make sure we get it
            for i = 1:length(testCase.test_property_names)
                prop_name = testCase.test_property_names{i};
                prop_data = stored_data{i};
                prop = test_dataset.(prop_name);
                testCase.verifyEqual(prop(:), prop_data);
            end
            % Now write the data file to disk and then read again
            test_dataset.write_to_disk(testCase.file_id)
            % Now read the data back to make sure we get it
            for i = 1:length(testCase.test_property_names)
                prop_name = testCase.test_property_names{i};
                prop_data = stored_data{i};
                prop = test_dataset.(prop_name);
                testCase.verifyEqual(prop(:), prop_data);
            end
            % Now read the data file back to memory
            test_dataset.read_into_memory();
            % Now read the data back to make sure we get it
            for i = 1:length(testCase.test_property_names)
                prop_name = testCase.test_property_names{i};
                prop_data = stored_data{i};
                prop = test_dataset.(prop_name);
                testCase.verifyEqual(prop(:), prop_data);
            end
        end

        function test_get_supertypes_returns_canonical_ancestry_order(testCase)
        % Verify that get_supertypes() returns canonical inheritance
        % application order, beginning with the root ancestor and ending
        % with the dataset type itself.
            ds = escdf_dataset('d1', 'unittesting_specification');
            testCase.verifyEqual(ds.get_supertypes(), ...
                {'parameter_set', 'activity_result', 'unittesting_specification'});
        end

        function test_get_dimension_names_returns_symbolic_dimensions(testCase)
        % Verify that get_dimension_names() returns symbolic dimensions from
        % the effective resolved specification.
            ds = escdf_dataset('d1', 'choicetesting_specification');
            dimension_names = ds.get_dimension_names();

            testCase.verifyTrue(any(strcmp(dimension_names, 'size_a')));
        end

        function test_istype_uses_canonical_inheritance_chain(testCase)
        % Verify that istype() still works correctly when driven by
        % canonical ancestry information.
            ds = escdf_dataset('d1', 'unittesting_specification');

            testCase.verifyTrue(ds.istype('unittesting_specification'));
            testCase.verifyTrue(ds.istype('activity_result'));
            testCase.verifyTrue(ds.istype('parameter_set'));
            testCase.verifyFalse(ds.istype('scalar'));
        end

        function test_dump_to_table_vector_dimension(testCase)
        % Verify that dump_to_table() returns a single-column table for a
        % simple one-dimensional property.
            ds = escdf_dataset('d1', 'tabletesting_specification');
            ds.vec = [10.0; 20.0; 30.0];

            table_out = ds.dump_to_table('num_points');

            testCase.verifyEqual(table_out.Properties.VariableNames, {'vec(:)'});
            testCase.verifyEqual(table_out{:, 'vec(:)'}, [10.0; 20.0; 30.0]);
        end

        function test_dump_to_table_middle_dimension_in_3d_property(testCase)
        % Verify that dump_to_table() correctly uses a middle symbolic
        % dimension as the row dimension for a three-dimensional property.
            ds = escdf_dataset('d1', 'tabletesting_specification');

            ds.mat = [
                1.0 2.0
                3.0 4.0
                5.0 6.0
            ];

            cube = zeros(2, 3, 2);

            cube(1,:,1) = [100.0, 102.0, 104.0];
            cube(1,:,2) = [101.0, 103.0, 105.0];

            cube(2,:,1) = [200.0, 202.0, 204.0];
            cube(2,:,2) = [201.0, 203.0, 205.0];

            ds.cube = cube;

            ds.labels = {'row1'; 'row2'; 'row3'};

            table_out = ds.dump_to_table('num_rows');

            testCase.verifyEqual(height(table_out), 3);

            % Matrix-derived columns
            testCase.verifyTrue(any(strcmp(table_out.Properties.VariableNames, 'mat(:,1)')));
            testCase.verifyTrue(any(strcmp(table_out.Properties.VariableNames, 'mat(:,2)')));
            testCase.verifyEqual(table_out{:, 'mat(:,1)'}, [1.0; 3.0; 5.0]);
            testCase.verifyEqual(table_out{:, 'mat(:,2)'}, [2.0; 4.0; 6.0]);

            % Labels
            testCase.verifyTrue(any(strcmp(table_out.Properties.VariableNames, 'labels(:)')));
            testCase.verifyEqual(table_out{:, 'labels(:)'}, {'row1'; 'row2'; 'row3'});

            % Cube-derived columns: verify row dimension comes from the
            % middle canonical dimension.
            testCase.verifyTrue(any(strcmp(table_out.Properties.VariableNames, 'cube(1,:,1)')));
            testCase.verifyTrue(any(strcmp(table_out.Properties.VariableNames, 'cube(2,:,2)')));
            testCase.verifyEqual(table_out{:, 'cube(1,:,1)'}, [100.0; 102.0; 104.0]);
            testCase.verifyEqual(table_out{:, 'cube(2,:,2)'}, [201.0; 203.0; 205.0]);
        end

        function test_new_dataset_starts_in_expected_state(testCase)
        % Verify that a newly constructed dataset starts memory-backed with
        % no pending changes.
            ds = escdf_dataset('d1', 'unittesting_specification');

            testCase.verifyEqual(ds.get_backing_state(), 'memory');
            testCase.verifyFalse(ds.get_has_pending_changes());
            testCase.verifyFalse(ds.get_has_modified_properties());
        end

        function test_dataset_assignment_sets_pending_changes(testCase)
        % Verify that assigning a property marks the dataset as having
        % pending changes.
            ds = escdf_dataset('d1', 'tabletesting_specification');
            testCase.verifyFalse(ds.get_has_pending_changes());

            ds.vec = [1.0; 2.0; 3.0];

            testCase.verifyTrue(ds.get_has_pending_changes());
            testCase.verifyEqual(ds.get_backing_state(), 'memory');
        end

        function test_loaded_dataset_starts_hdf5_native_with_no_pending_changes(testCase)
        % Verify that a dataset loaded from disk starts HDF5-native and has
        % no pending changes.
            outfile = fullfile(testCase.temp_folder, 'dataset_state_roundtrip.h5');

            f = escdf();
            md = escdf_dataset('meta1', 'scalar', 'Scalar metadata');
            md.value = 2.0;
            md.unit = {'g'};
            testCase.verifyTrue(md.validate());

            f.add_metadata(md);
            f.write_to_disk(outfile, true);

            loaded = escdf.load(outfile);
            loaded_md = loaded.get_metadata('meta1');

            testCase.verifyEqual(loaded_md.get_backing_state(), 'hdf5_native');
            testCase.verifyFalse(loaded_md.get_has_pending_changes());
            testCase.verifyFalse(loaded_md.get_has_modified_properties());
        end

        function test_dataset_write_to_disk_sets_hdf5_native_and_clears_pending_changes(testCase)
        % Verify that writing a dataset to disk sets it HDF5-native and
        % clears pending changes.
            gid = H5G.create(testCase.file_id, 'meta1', 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');

            ds = escdf_dataset('meta1', 'scalar', 'Scalar metadata');
            ds.value = 2.0;
            ds.unit = {'g'};

            testCase.verifyTrue(ds.get_has_pending_changes());
            testCase.verifyEqual(ds.get_backing_state(), 'memory');

            ds.write_to_disk(gid);

            testCase.verifyEqual(ds.get_backing_state(), 'hdf5_native');
            testCase.verifyFalse(ds.get_has_pending_changes());

            H5G.close(gid);
        end

        function test_dataset_read_into_memory_sets_memory_backing_state(testCase)
        % Verify that reading a dataset into memory updates its dataset-level
        % backing state to memory.
            outfile = fullfile(testCase.temp_folder, 'dataset_read_into_memory_state.h5');

            f = escdf();
            md = escdf_dataset('meta1', 'scalar', 'Scalar metadata');
            md.value = 2.0;
            md.unit = {'g'};
            f.add_metadata(md);
            f.write_to_disk(outfile, true);

            loaded = escdf.load(outfile);
            loaded_md = loaded.get_metadata('meta1');

            testCase.verifyEqual(loaded_md.get_backing_state(), 'hdf5_native');

            loaded_md.read_into_memory();

            testCase.verifyEqual(loaded_md.get_backing_state(), 'memory');
            testCase.verifyEqual(loaded_md.value.get_backing_state(), 'memory');
            testCase.verifyEqual(loaded_md.unit.get_backing_state(), 'memory');
        end

        function test_attached_cloned_dataset_starts_memory_backed_and_not_pending_changes(testCase)
        % Verify that an attached cloned dataset wrapper starts memory-backed
        % and without pending changes.
            source_file_path = fullfile(testCase.temp_folder, 'attached_clone_state.h5');

            source_file = escdf();
            md = escdf_dataset('meta1', 'scalar', 'Scalar metadata');
            md.value = 2.0;
            md.unit = {'g'};
            source_file.add_metadata(md);
            source_file.write_to_disk(source_file_path, true);

            loaded = escdf.load(source_file_path, true);
            loaded_md = loaded.get_metadata('meta1');

            target = escdf();
            target.add_metadata(loaded_md);

            attached_md = target.get_metadata('meta1');

            testCase.verifyEqual(attached_md.get_backing_state(), 'memory');
            testCase.verifyFalse(attached_md.get_has_pending_changes());
        end
    end

end