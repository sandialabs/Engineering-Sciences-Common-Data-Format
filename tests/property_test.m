classdef property_test < matlab.unittest.TestCase
    properties
        temp_folder;
        file_id;
        original_path;
        source_folder;
    end

    properties (TestParameter)
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
        stride = {...
            1,...
            2,...
            };
        in_memory = {...
            true,...
            false...
            };
        ragged = {...
            true,...
            false...
            };
    end

    methods (TestMethodSetup)
        function createHDF5File(testCase)
            current_file_folder = fileparts(mfilename('fullpath'));
            testCase.source_folder = fullfile(current_file_folder, '..', 'escdf');
            testCase.temp_folder = tempname;
            testCase.original_path = addpath(testCase.source_folder);
            mkdir(testCase.temp_folder);
            testCase.file_id = H5F.create(fullfile(testCase.temp_folder,'escdf_property_test.h5'), 'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');
        end
    end

    methods (TestMethodTeardown)
        function deleteStoredData(testCase)
            H5F.close(testCase.file_id);
            rmdir(testCase.temp_folder,'s');
            path(testCase.original_path);
        end
    end

    methods (Static)
        function [prop, parent_dataset, root_file, parent_group_id] = make_hdf5_property_with_logical_context(testCase, parent_name, property_name, data_type, data_size, ragged, in_memory)
        % Create a property inside a minimal logical ESCDF context.
        %
        % Parameters
        % ----------
        % testCase : property_test
        %     Test case object containing an open HDF5 file id.
        % parent_name : char
        %     Name of the logical parent dataset and HDF5 group.
        % property_name : char
        %     Property name.
        % data_type : char
        %     ESCDF property datatype.
        % data_size : numeric array
        %     Property size.
        % ragged : logical
        %     Whether the property is ragged.
        % in_memory : logical
        %     If true, create the property in memory. If false, create it
        %     in the parent HDF5 group.
        %
        % Returns
        % -------
        % prop : escdf_property
        %     Created property.
        % parent_dataset : escdf_dataset
        %     Logical parent dataset.
        % root_file : escdf
        %     Logical root container.
        % parent_group_id : numeric
        %     HDF5 group id for the logical parent dataset.
            parent_group_id = H5G.create(testCase.file_id, parent_name, ...
                'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');

            root_file = escdf();
            root_file.set_hdf5_location(HDF5Location.from_hdf5_id(testCase.file_id));

            parent_dataset = escdf_dataset(parent_name, 'scalar', 'Property test logical parent');
            root_file.insert_metadata_native(parent_dataset);

            if in_memory
                prop = escdf_property(property_name, data_type, data_size, ...
                    'ragged', ragged);
            else
                prop = escdf_property(property_name, data_type, data_size, ...
                    'hdf5groupid', parent_group_id, ...
                    'ragged', ragged);
            end

            prop.set_logical_parent(parent_dataset);
        end
    end

    methods (Test)
        function testStorageAndRecall(testCase, data_type, data_size, stride, in_memory, ragged)
            ndim = length(data_size);
            parent_group_id = [];
            try
                if in_memory
                    name = [data_type,sprintf('_from_memory_ndim_%d_stride_%d',ndim,stride)];
                else
                    name = [data_type,sprintf('_on_disk_ndim_%d_stride_%d',ndim,stride)];
                end

                parent_name = [name, '_parent'];

                [prop, parent_dataset, root_file, parent_group_id] = ...
                    property_test.make_hdf5_property_with_logical_context( ...
                        testCase, ...
                        parent_name, ...
                        name, ...
                        data_type, ...
                        data_size, ...
                        ragged, ...
                        in_memory); %#ok<ASGLU>
            catch ME
                if ~isempty(parent_group_id)
                    try
                        H5G.close(parent_group_id);
                    catch
                    end
                end
                testCase.verifyEqual(ME.message,sprintf('Variable-length arrays of objects with type "%s" are not supported.',data_type))
                return
            end
            
            testCase.verifyEqual(name,prop.get_name())
            testCase.verifyEqual(data_type,prop.get_format())
            testCase.verifyEqual(data_size,prop.get_size())

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

            if length(data_size) == 0
                prop(:) = data(:);
                testCase.verifyEqual(prop(:),data);
            elseif length(data_size) == 1
                prop(strides{:}) = data(:);
                testCase.verifyEqual(prop(strides{:}),data(:));
            else
                prop(strides{:}) = data;
                testCase.verifyEqual(prop(strides{:}),data);
            end

            testCase.verifyEqual(prop.isinmemory(),in_memory);
            testCase.verifyEqual(prop.isragged(), ragged);

            if in_memory
                prop.write_to_disk(parent_group_id);
                if length(data_size) == 0
                    testCase.verifyEqual(prop(:),data);
                elseif length(data_size) == 1
                    testCase.verifyEqual(prop(strides{:}),data(:));
                else
                    testCase.verifyEqual(prop(strides{:}),data);
                end
                testCase.verifyEqual(prop.isinmemory(),false);
            end
            prop.read_into_memory();
            if length(data_size) == 0
                testCase.verifyEqual(prop(:),data);
            elseif length(data_size) == 1
                testCase.verifyEqual(prop(strides{:}),data(:));
            else
                testCase.verifyEqual(prop(strides{:}),data);
            end
            testCase.verifyEqual(prop.isinmemory(),true);
            if ~isempty(parent_group_id)
                H5G.close(parent_group_id);
            end
        end

        function test_new_in_memory_property_starts_memory_backed(testCase)
            prop = escdf_property('p1', 'f8', [3]);
            testCase.verifyEqual(prop.get_backing_state(), 'memory');
            testCase.verifyTrue(prop.isinmemory());
        end

        function test_new_hdf5_property_starts_hdf5_native(testCase)
            prop = escdf_property('p1', 'f8', [3], 'hdf5groupid', testCase.file_id);
            testCase.verifyEqual(prop.get_backing_state(), 'hdf5_native');
            testCase.verifyFalse(prop.isinmemory());
        end

        function test_loaded_property_starts_hdf5_native(testCase)
            [prop, parent_dataset, root_file, parent_group_id] = ...
                property_test.make_hdf5_property_with_logical_context( ...
                testCase, ...
                'p1_parent', ...
                'pi', ...
                'f8', ...
                [3], ...
                false, ...
                false); %#ok<ASGLU>
            prop(:) = [1.0; 2.0; 3.0];

            loaded = escdf_property.load(prop.get_h5d_id());
            testCase.verifyEqual(loaded.get_backing_state(), 'hdf5_native');
            testCase.verifyFalse(loaded.isinmemory());
        end

        function test_read_into_memory_sets_backing_state_to_memory(testCase)
            prop = escdf_property('p1', 'f8', [3], 'hdf5groupid', testCase.file_id);
            prop(:) = [1.0; 2.0; 3.0];

            prop.read_into_memory();

            testCase.verifyEqual(prop.get_backing_state(), 'memory');
            testCase.verifyTrue(prop.isinmemory());
            testCase.verifyEqual(prop(:), [1.0; 2.0; 3.0]);
        end

        function test_compute_hyperslab_arguments_returns_expected_outputs(testCase)
        % Verify that compute_hyperslab_arguments returns the expected
        % start, stride, and count arrays for a representative indexing
        % operation.
            prop = escdf_property('p1', 'f8', [10, 20, 30]);

            [start, stride, count] = prop.compute_hyperslab_arguments( ...
                {2:3:8, ':', [5 10 15 20]});

            testCase.verifyEqual(start, [2, 1, 5]);
            testCase.verifyEqual(stride, [3, 1, 5]);
            testCase.verifyEqual(count, [3, 20, 4]);
        end

        function test_compute_hyperslab_arguments_scalar_like_indexing(testCase)
        % Verify that scalar properties accept ':' indexing through the
        % hyperslab helper.
            prop = escdf_property('p1', 'f8', [5]);

            [start, stride, count] = prop.compute_hyperslab_arguments({':'});

            testCase.verifyEqual(start, 1);
            testCase.verifyEqual(stride, 1);
            testCase.verifyEqual(count, 5);
        end

        function test_hdf5_location_object_compares_same_location(testCase)
            [prop1, parent_dataset, root_file, parent_group_id] = ...
                property_test.make_hdf5_property_with_logical_context( ...
                testCase, ...
                'p1_parent', ...
                'p1', ...
                'f8', ...
                [3], ...
                false, ...
                false); %#ok<ASGLU>
            prop1(:) = [1.0; 2.0; 3.0];

            dataset_id = H5D.open(parent_group_id, 'p1');
            prop2 = escdf_property.load(dataset_id);

            testCase.verifyFalse(prop1 == prop2);
            testCase.verifyTrue(prop1.same_backing_location_as(prop2));

            H5D.close(dataset_id);
        end

        function test_memory_properties_do_not_have_same_backing_location(testCase)
            prop1 = escdf_property('p1', 'f8', [3]);
            prop2 = escdf_property('p1', 'f8', [3]);

            testCase.verifyTrue(isempty(prop1.get_hdf5_location()));
            testCase.verifyTrue(isempty(prop2.get_hdf5_location()));
            testCase.verifyFalse(prop1.same_backing_location_as(prop2));
        end

        function test_target_hdf5_location_uses_group_and_property_name(testCase)
            group_id = H5G.create(testCase.file_id, 'my_group', 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');

            prop = escdf_property('p1', 'f8', [3]);
            location = prop.get_target_hdf5_location(group_id);

            testCase.verifyEqual(location.object_path, '/my_group/p1');

            H5G.close(group_id);
        end

        function test_assignment_to_loaded_native_property_writes_through_when_logical_and_backing_match(testCase)
            outfile = fullfile(testCase.temp_folder, 'native_assignment.h5');

            f = escdf();
            md = escdf_dataset('meta1', 'scalar', 'Scalar metadata');
            md.value = 2.0;
            md.unit = {'g'};
            f.add_metadata(md);
            f.write_to_disk(outfile, true);

            loaded = escdf.load(outfile, false);
            loaded_md = loaded.get_metadata('meta1');

            testCase.verifyTrue(loaded_md.value.can_write_through_current_hdf5_backing());

            loaded_md.value(:) = single(5.0);

            testCase.verifyFalse(loaded_md.value.isinmemory());
            testCase.verifyEqual(double(loaded_md.value(:)), 5.0);

            file_id = H5F.open(outfile, 'H5F_ACC_RDONLY', 'H5P_DEFAULT');
            dataset_id = H5D.open(file_id, '/meta1/value');
            disk_value = H5D.read(dataset_id);
            H5D.close(dataset_id);
            H5F.close(file_id);

            testCase.verifyEqual(double(disk_value), 5.0);
        end

        function test_assignment_to_attached_hdf5_backed_property_materializes_and_preserves_source(testCase)
            source_path = fullfile(testCase.temp_folder, 'source_assignment.h5');

            source = escdf();
            md = escdf_dataset('meta1', 'scalar', 'Scalar metadata');
            md.value = 2.0;
            md.unit = {'g'};
            source.add_metadata(md);
            source.write_to_disk(source_path, true);

            loaded = escdf.load(source_path, false);
            loaded_md = loaded.get_metadata('meta1');

            target = escdf();
            target.add_metadata(loaded_md);
            attached_md = target.get_metadata('meta1');

            testCase.verifyFalse(attached_md.value.can_write_through_current_hdf5_backing());
            testCase.verifyTrue(attached_md.value.same_backing_location_as(loaded_md.value));

            attached_md.value(:) = 9.0;

            testCase.verifyTrue(attached_md.value.isinmemory());
            testCase.verifyTrue(isempty(attached_md.value.get_hdf5_location()));
            testCase.verifyEqual(double(attached_md.value(:)), 9.0);

            testCase.verifyFalse(loaded_md.value.isinmemory());
            testCase.verifyEqual(double(loaded_md.value(:)), 2.0);

            file_id = H5F.open(source_path, 'H5F_ACC_RDONLY', 'H5P_DEFAULT');
            dataset_id = H5D.open(file_id, '/meta1/value');
            disk_value = H5D.read(dataset_id);
            H5D.close(dataset_id);
            H5F.close(file_id);

            testCase.verifyEqual(double(disk_value), 2.0);
        end

        function test_assignment_to_removed_hdf5_backed_property_materializes_and_preserves_source(testCase)
            outfile = fullfile(testCase.temp_folder, 'removed_assignment.h5');

            f = escdf();
            md = escdf_dataset('meta1', 'scalar', 'Scalar metadata');
            md.value = 2.0;
            md.unit = {'g'};
            f.add_metadata(md);
            f.write_to_disk(outfile, true);

            loaded = escdf.load(outfile, false);
            removed = loaded.remove_metadata('meta1');

            testCase.verifyEmpty(removed.get_logical_parent());
            testCase.verifyFalse(removed.value.can_write_through_current_hdf5_backing());

            removed.value(:) = 7.0;

            testCase.verifyTrue(removed.value.isinmemory());
            testCase.verifyTrue(isempty(removed.value.get_hdf5_location()));
            testCase.verifyEqual(double(removed.value(:)), 7.0);

            file_id = H5F.open(outfile, 'H5F_ACC_RDONLY', 'H5P_DEFAULT');
            dataset_id = H5D.open(file_id, '/meta1/value');
            disk_value = H5D.read(dataset_id);
            H5D.close(dataset_id);
            H5F.close(file_id);

            testCase.verifyEqual(double(disk_value), 2.0);
        end

    end
    
end