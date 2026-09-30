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

    methods (Test)
        function testStorageAndRecall(testCase, data_type, data_size, stride, in_memory, ragged)
            ndim = length(data_size);
            try
                if in_memory
                    name = [data_type,sprintf('_from_memory_ndim_%d_stride_%d',ndim,stride)];
                    prop = escdf_property(name,data_type,data_size,'ragged',ragged);
                else
                    name = [data_type,sprintf('_on_disk_ndim_%d_stride_%d',ndim,stride)];
                    prop = escdf_property(name,data_type,data_size,'hdf5groupid',testCase.file_id,'ragged',ragged);
                end
            catch ME
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
                prop.write_to_disk(testCase.file_id);
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
            prop = escdf_property('p1', 'f8', [3], 'hdf5groupid', testCase.file_id);
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

        function test_mark_external_backing_sets_external_state(testCase)
            prop = escdf_property('p1', 'f8', [3], 'hdf5groupid', testCase.file_id);

            prop.mark_external_backing();

            testCase.verifyEqual(prop.get_backing_state(), 'hdf5_external');
            testCase.verifyFalse(prop.isinmemory());
        end

        function test_assignment_to_external_backed_property_materializes_to_memory(testCase)
            prop = escdf_property('p1', 'f8', [3], 'hdf5groupid', testCase.file_id);
            prop(:) = [1.0; 2.0; 3.0];

            prop.mark_external_backing();
            testCase.verifyEqual(prop.get_backing_state(), 'hdf5_external');
            testCase.verifyFalse(prop.isinmemory());

            prop(:) = [10.0; 20.0; 30.0];

            testCase.verifyEqual(prop.get_backing_state(), 'memory');
            testCase.verifyTrue(prop.isinmemory());
            testCase.verifyEqual(prop(:), [10.0; 20.0; 30.0]);
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

    end

end