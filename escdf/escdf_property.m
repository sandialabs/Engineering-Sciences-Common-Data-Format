classdef escdf_property < handle
% ESCDF_PROPERTY Typed ESCDF dataset property.
%
% An escdf_property stores one named property belonging to an
% escdf_dataset. Properties can exist either fully in memory or as
% datasets backed by HDF5 storage.
%
% Parameters
% ----------
% name : char
%     Property name.
% format : char
%     ESCDF datatype code such as f8, c16, u8, str, or bytes.
% size : numeric array
%     Property shape as defined by the active specification.
% Optional name/value arguments:
%   'data'
%       Initial data to assign.
%   'ragged'
%       Logical flag indicating variable-length numeric arrays.
%   'hdf5groupid'
%       HDF5 group identifier in which a new on-disk dataset should be
%       created.
%
% Notes
% -----
% Properties with datatype str or bytes do not support ragged mode.
% bytes values are represented as arrays of uint8.
%
% See Also
% --------
% escdf_dataset
    properties (Access=private, Constant)
        VERBOSE=false
    end

    properties (Access = private)
        name
        format
        size
        data
        inmemory
        ragged
        h5d_id
        h5type_id
        backing_state
    end

    methods
        function obj = escdf_property(name, format, size, varargin)
        % Initialize an ESCDF property.
        %
        % Parameters
        % ----------
        % name : char
        %     Property name.
        % format : char
        %     ESCDF datatype code.
        % size : numeric array
        %     Property shape.
        % Optional name/value arguments:
        %   'data'
        %       Initial data to assign.
        %   'ragged'
        %       If true, store variable-length numeric arrays.
        %   'hdf5groupid'
        %       Group identifier in which to create a new HDF5 dataset.
        %
        % Raises
        % ------
        % error
        %     Raised if unsupported constructor options are supplied or if
        %     an unsupported ragged datatype is requested.
            obj.name = name;
            obj.format = format;
            obj.size = size;
            obj.inmemory = true;
            obj.ragged = false;
            obj.backing_state = 'memory';
            data = missing;
            h5g_id = missing;
            obj.h5d_id = missing;
            if mod(length(varargin), 2) ~= 0
                error('Optional Arguments must come in pairs.');
            end
            for i = 1:2:length(varargin)
                varname = varargin{i};
                varvalue = varargin{i+1};
                if strcmpi(varname,'ragged')
                    obj.ragged = varvalue;
                elseif strcmpi(varname,'hdf5groupid')
                    obj.inmemory = false;
                    h5g_id = varvalue;
                elseif strcmpi(varname,'data')
                    data = varvalue;
                else
                    error(['Unknown option: ', name]);
                end
            end
            
            obj.set_h5type(obj.format);

            if ~check_if_missing(h5g_id)
                if isempty(size)
                    space_id = H5S.create('H5S_SCALAR');
                else
                    space_id = H5S.create_simple(length(size),size,size);
                end
                obj.h5d_id = H5D.create(h5g_id,obj.name,obj.h5type_id, space_id, 'H5P_DEFAULT');
                H5S.close(space_id)
                attr_space_id = H5S.create('H5S_SCALAR');
                str_type_id = H5T.copy('H5T_C_S1');
                H5T.set_size(str_type_id, 'H5T_VARIABLE');
                attr_id = H5A.create(obj.h5d_id, 'data_type', str_type_id, attr_space_id, 'H5P_DEFAULT');
                H5A.write(attr_id,str_type_id,obj.format);
                H5A.close(attr_id);
                H5T.close(str_type_id);
                H5S.close(attr_space_id);
                obj.backing_state = 'hdf5_native';
            end

            if obj.inmemory
                if length(size) < 2
                    size = [size,1];
                end
                if strcmpi(obj.format,'str')
                    obj.data = cell(size);
                    obj.data(:) = {''};
                elseif strcmpi(obj.format,'bytes')
                    obj.data = cell(size);
                    obj.data(:) = {uint8([])};
                elseif obj.ragged
                    obj.data = cell(size);
                    matlab_fn = obj.matlab_type();
                    if ~check_if_missing(matlab_fn)
                        obj.data(:) = {matlab_fn(zeros(0))};
                    end
                else
                    matlab_fn = obj.matlab_type();
                    if ~check_if_missing(matlab_fn)
                        obj.data = matlab_fn(zeros(size));
                    else
                        obj.data = zeros(size);
                    end
                end
            else
                obj.data = missing;
            end
            if ~check_if_missing(data)
                indices = repmat({':'}, 1, length(size));
                obj(indices{:}) = data;
            end
        end

        % Overload subsref for indexing
        function varargout = subsref(obj, S)
        % Retrieve property data by index or field access.
        %
        % Parameters
        % ----------
        % S : struct
        %     MATLAB indexing structure produced by subscripting syntax.
        %
        % Returns
        % -------
        % varargout : cell
        %     Indexed property data or regular object property access
        %     results.
        %
        % Notes
        % -----
        % For on-disk datasets, indexing reads the requested region from
        % HDF5 storage.
            switch S(1).type
                case '()'
                    if obj.inmemory
                        if isequal(S.subs,{':'})
                            S.subs = repmat({':'},1,length(obj.size));
                        end
                        varargout{1} = builtin('subsref', obj.data, S);
                    else
                        % builtin('disp',S)
                        if ~isempty(obj.size)
                            % Need to compute the start, step, and stride
                            [start,stride,count] = obj.compute_hyperslab_arguments(S.subs);
                            file_space_id = H5D.get_space(obj.h5d_id);
                            H5S.select_hyperslab(file_space_id,'H5S_SELECT_SET',start-1,stride,count,[])
                            mem_space_id = H5S.create_simple(length(obj.size),count,count);
                            data = H5D.read(obj.h5d_id,obj.h5type_id,mem_space_id,file_space_id,'H5P_DEFAULT');
                        else
                            if escdf_property.VERBOSE
                                disp(S.subs)
                            end
                            if length(S.subs) > 1 || (isnumeric(S.subs{1}) && S.subs{1} ~= 1)
                                error('Scalar variables stored in an HDF file must be indexed with '':'' or 1')
                            end
                            data = H5D.read(obj.h5d_id,obj.h5type_id, 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT');
                            if strcmpi(obj.format,'str')
                                data = {data};
                            end
                        end
                        if strcmpi(obj.format,'c8') || strcmpi(obj.format,'c16')
                            data = complex(data.r,data.i);
                        end
                        if length(obj.size) > 1
                            varargout{1} = permute(data,ndims(data):-1:1);
                        else
                            varargout{1} = data;
                        end
                        if ~isempty(obj.size)
                            H5S.close(mem_space_id);
                            H5S.close(file_space_id);
                        end
                    end
                case '.'
                    [varargout{1:nargout}] = builtin('subsref', obj, S);
                otherwise
                    error(['Unsupported indexing type ',S(1).type]);
            end
        end
        
        % Overload subsasgn for assignment
        function obj = subsasgn(obj, S, value)
        % Assign property data by index or field access.
        %
        % Parameters
        % ----------
        % S : struct
        %     MATLAB indexing structure produced by assignment syntax.
        % value : array-like
        %     Value to assign.
        %
        % Notes
        % -----
        % For on-disk datasets, assignment writes directly into HDF5
        % storage.
            switch S(1).type
                case '()'
                    if strcmp(obj.backing_state, 'hdf5_external')
                        obj.read_into_memory();
                    end
                    if obj.inmemory
                        if any(strcmpi({'i1','i2','i4','i8','u1','u2','u4','u8','f4','f8'},obj.format))
                            % Clip imaginary part if it shouldn't exist
                            if obj.ragged
                                value = cellfun(@real, value, 'UniformOutput',false);
                            else
                                value = real(value);
                            end
                        end
                        obj.data = builtin('subsasgn', obj.data, S, value);
                    else
                        if ~isempty(obj.size)
                            [start,stride,count] = obj.compute_hyperslab_arguments(S.subs);
                            file_space_id = H5D.get_space(obj.h5d_id);
                            H5S.select_hyperslab(file_space_id,'H5S_SELECT_SET',start-1,stride,count,[])
                            mem_space_id = H5S.create_simple(length(obj.size),count,count);
                        end
                        data = permute(value,ndims(value):-1:1);
                        if strcmpi(obj.format,'c8')
                            data = struct('r',single(real(data)),'i',single(imag(data)));
                        elseif strcmpi(obj.format,'c16')
                            data = struct('r',double(real(data)),'i',double(imag(data)));
                        end
                        if ~isempty(obj.size)
                            H5D.write(obj.h5d_id,obj.h5type_id,mem_space_id,file_space_id,'H5P_DEFAULT',data);
                            H5S.close(mem_space_id);
                            H5S.close(file_space_id);
                        else
                            if escdf_property.VERBOSE
                                disp(S.subs)
                            end
                            if length(S.subs) > 1 || (isnumeric(S.subs{1}) && S.subs{1} ~= 1)
                                error('Scalar variables stored in an HDF file must be indexed with '':'' or 1')
                            end
                            H5D.write(obj.h5d_id,obj.h5type_id, 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', data);
                        end
                    end
                case '.'
                    obj = builtin('subsasgn', obj, S, value);
                otherwise
                    error(['Unsupported assignment type ',S(1).type]);
            end
        end

        function disp(obj)
            fprintf('%s\n\n',obj.repr())
        end

        function out = repr(obj)
        % Return a text representation of the property.
        %
        % Returns
        % -------
        % out : char
        %     Human-readable summary including storage mode, name,
        %     datatype, and shape.
            if obj.isinmemory
                memory_string = 'in memory';
            else
                memory_string = 'on disk';
            end
            out = sprintf('escdf_property (%s): %s, %s, (%s)',memory_string,obj.name,obj.format,num2str(obj.size));
        end

        function id = get_h5d_id(obj)
            id = obj.h5d_id;
        end

        function obj = write_to_disk(obj,h5g_id)
        % Write the property to an HDF5 group.
        %
        % Parameters
        % ----------
        % h5g_id : numeric
        %     Target HDF5 group identifier in which the property dataset
        %     should be created.
        %
        % Notes
        % -----
        % If the property is already on disk, the method issues a warning
        % and does not rewrite the data.
            if ~obj.inmemory
                % TODO: This needs to be updated because it could be on disk but on a different
                % external hdf5 file.
                warning('Call to the write_to_disk method is unnecessary as the data is already on disk.  Data was not written.')
                return
            else
                if isempty(obj.size)
                    space_id = H5S.create('H5S_SCALAR');
                else
                    space_id = H5S.create_simple(length(obj.size),obj.size,obj.size);
                end
                obj.h5d_id = H5D.create(h5g_id,obj.name,obj.h5type_id, space_id, 'H5P_DEFAULT');
                H5S.close(space_id);
                data = permute(obj.data,ndims(obj.data):-1:1);
                if strcmpi(obj.format,'c8')
                    data = struct('r',single(real(data)),'i',single(imag(data)));
                elseif strcmpi(obj.format,'c16')
                    data = struct('r',double(real(data)),'i',double(imag(data)));
                end
                H5D.write(obj.h5d_id,obj.h5type_id,'H5S_ALL','H5S_ALL','H5P_DEFAULT',data);
                obj.data = missing;
                obj.inmemory = false;
                attr_space_id = H5S.create('H5S_SCALAR');
                str_type_id = H5T.copy('H5T_C_S1');
                H5T.set_size(str_type_id, 'H5T_VARIABLE');
                attr_id = H5A.create(obj.h5d_id, 'data_type', str_type_id, attr_space_id, 'H5P_DEFAULT');
                H5A.write(attr_id,str_type_id,obj.format);
                H5A.close(attr_id);
                H5T.close(str_type_id);
                H5S.close(attr_space_id);
                obj.backing_state = 'hdf5_native';
            end
        end

        function obj = read_into_memory(obj)
        % Load the property fully into memory.
        %
        % Notes
        % -----
        % If the property is already stored in memory, the method issues a
        % warning and does nothing.
            if obj.inmemory
                warning(['Call to the read_into_memory method is unnecessary for dataset "',obj.name,'" as the data is already in memory.  Data was not read for this dataset.'])
                return
            else
                indices = repmat({':'}, 1, length(obj.size));
                S.type = '()';
                S.subs = {':'};
                data = obj.subsref(S);
                H5D.close(obj.h5d_id)
                obj.inmemory = true;
                obj.h5d_id = missing;
                size = obj.size;
                if length(size) < 2
                    size = [size,1];
                end
                if strcmpi(obj.format,'str')
                    obj.data = cell(size);
                    obj.data(:) = {''};
                elseif strcmpi(obj.format,'bytes')
                    obj.data = cell(size);
                    obj.data(:) = {uint8([])};
                elseif obj.ragged
                    obj.data = cell(size);
                    matlab_fn = obj.matlab_type();
                    if ~check_if_missing(matlab_fn)
                        obj.data(:) = {matlab_fn(zeros(0))};
                    end
                else
                    fn_handle = obj.matlab_type();
                    obj.data = fn_handle(zeros(size));
                end
                obj.subsasgn(S,data);
                obj.backing_state = 'memory';
            end
        end

        function mark_external_backing(obj)
        % Mark the property as externally backed.
        %
        % Notes
        % -----
        % This is intended for copied/attached property wrappers that still
        % reference an HDF5 source outside their new native context.
            if strcmp(obj.backing_state, 'hdf5_native')
                obj.backing_state = 'hdf5_external';
            end
        end

        function delete(obj)
            if ~obj.inmemory% && ~ismissing(obj.h5d_id)
                H5D.close(obj.h5d_id)
            end
        end

        function ind = end(obj,k,n)
            ind = obj.size(k);
        end

        function [start,stride,count] = compute_hyperslab_arguments(obj,subs)
            if escdf_property.VERBOSE
                disp('Indexing Operation:')
                disp(subs)
            end
            if length(subs) == 1 && ischar(subs{1}) && subs{1}==':'
                subs = repmat(subs,1,length(obj.size));
            end
            if length(subs) ~= length(obj.size)
                error(['Indexing operation did not provide the correct number of indices (',num2str(length(subs)),') for the dimensions of this object (',num2str(length(obj.size)),')'])
            end
            start = zeros(1,length(subs));
            stride = start;
            count = start;
            for i = 1:length(subs)
                sub = subs{i};
                if isnumeric(sub)
                    strides = diff(sub);
                    if isempty(strides)
                        stride(i) = 1;
                    elseif all(strides==strides(1))
                        stride(i) = strides(1);
                    else
                        error('Indexing to HDF5 file must be evenly spaced')
                    end
                    count(i) = length(sub);
                    start(i) = sub(1);
                elseif strcmpi(sub,':')
                    start(i) = 1;
                    count(i) = obj.end(i,length(subs));
                    stride(i) = 1;
                else
                    error(['Unknown Subscript ',num2str(subs),' at index ',num2str(i)])
                end
            end
        end

        function outval = isinmemory(obj)
        % Return whether the property is currently stored in memory.
        %
        % Returns
        % -------
        % outval : logical
        %     True if the property is stored in memory, false if it is
        %     backed by HDF5 storage.
            outval = obj.inmemory;
        end

        function outval = isragged(obj)
        % Return whether the property is ragged.
        %
        % Returns
        % -------
        % outval : logical
        %     True if the property stores variable-length numeric arrays.
            outval = obj.ragged;
        end

        function name = get_name(obj)
        % Return the property name.
        %
        % Returns
        % -------
        % name : char
        %     Property name.
            name = obj.name;
        end

        function size = get_size(obj)
        % Return the property shape.
        %
        % Returns
        % -------
        % size : numeric array
        %     Property shape.
            size = obj.size;
        end

        function format = get_format(obj)
        % Return the ESCDF datatype code.
        %
        % Returns
        % -------
        % format : char
        %     ESCDF datatype code.
            format = obj.format;
        end

        function data = get_data(obj)
        % Return the full property data.
        %
        % Returns
        % -------
        % data : array-like
        %     Full property contents, read from memory or disk as needed.
            if obj.inmemory
                data = obj.data;
            else
                data = obj(:);
            end
        end

        function out = get_backing_state(obj)
        % Return the property's backing state.
        %
        % Returns
        % -------
        % out : char
        %     Property backing state.
            out = obj.backing_state;
        end

        function obj = set_h5type(obj,escdf_type)
        % Configure the HDF5 datatype corresponding to an ESCDF datatype.
        %
        % Parameters
        % ----------
        % escdf_type : char
        %     ESCDF datatype code.
        %
        % Notes
        % -----
        % This method selects the appropriate HDF5 primitive, variable-
        % length, or compound datatype used for storage.
            % Set up the type of data
            switch lower(escdf_type)
                case 'i1'
                    if obj.ragged
                        obj.h5type_id = H5T.vlen_create('H5T_STD_I8LE');
                    else
                        obj.h5type_id = 'H5T_STD_I8LE';
                    end
                case 'i2'
                    if obj.ragged
                        obj.h5type_id = H5T.vlen_create('H5T_STD_I16LE');
                    else
                        obj.h5type_id = 'H5T_STD_I16LE';
                    end
                case 'i4'
                    if obj.ragged
                        obj.h5type_id = H5T.vlen_create('H5T_STD_I32LE');
                    else
                        obj.h5type_id = 'H5T_STD_I32LE';
                    end
                case 'i8'
                    if obj.ragged
                        obj.h5type_id = H5T.vlen_create('H5T_STD_I64LE');
                    else
                        obj.h5type_id = 'H5T_STD_I64LE';
                    end
                case 'u1'
                    if obj.ragged
                        obj.h5type_id = H5T.vlen_create('H5T_STD_U8LE');
                    else
                        obj.h5type_id = 'H5T_STD_U8LE';
                    end
                case 'u2'
                    if obj.ragged
                        obj.h5type_id = H5T.vlen_create('H5T_STD_U16LE');
                    else
                        obj.h5type_id = 'H5T_STD_U16LE';
                    end
                case 'u4'
                    if obj.ragged
                        obj.h5type_id = H5T.vlen_create('H5T_STD_U32LE');
                    else
                        obj.h5type_id = 'H5T_STD_U32LE';
                    end
                case 'u8'
                    if obj.ragged
                        obj.h5type_id = H5T.vlen_create('H5T_STD_U64LE');
                    else
                        obj.h5type_id = 'H5T_STD_U64LE';
                    end
                case 'f4'
                    if obj.ragged
                        obj.h5type_id = H5T.vlen_create('H5T_IEEE_F32LE');
                    else
                        obj.h5type_id = 'H5T_IEEE_F32LE';
                    end
                case 'f8'
                    if obj.ragged
                        obj.h5type_id = H5T.vlen_create('H5T_IEEE_F64LE');
                    else
                        obj.h5type_id = 'H5T_IEEE_F64LE';
                    end
                case 'str'
                    tid = H5T.copy('H5T_C_S1');
                    H5T.set_size(tid,'H5T_VARIABLE');
                    if obj.ragged
                        error('Variable-length arrays of objects with type "str" are not supported.')
                    else
                        obj.h5type_id = tid;
                    end
                case 'bytes'
                    if obj.ragged
                        error('Variable-length arrays of objects with type "bytes" are not supported.')
                    else
                        obj.h5type_id = H5T.vlen_create('H5T_STD_U8LE');
                    end
                case 'c8'
                    tid = H5T.create('H5T_COMPOUND',8);
                    H5T.insert(tid,'r',0,'H5T_IEEE_F32LE');
                    H5T.insert(tid,'i',4,'H5T_IEEE_F32LE');
                    if obj.ragged
                        error('Variable-length arrays of objects with type "c8" are not supported.')
                        % obj.h5type_id = H5T.vlen_create(tid);
                    else
                        obj.h5type_id = tid;
                    end
                case 'c16'
                    tid = H5T.create('H5T_COMPOUND',16);
                    H5T.insert(tid,'r',0,'H5T_IEEE_F64LE');
                    H5T.insert(tid,'i',8,'H5T_IEEE_F64LE');
                    if obj.ragged
                        error('Variable-length arrays of objects with type "c16" are not supported.')
                        % obj.h5type_id = H5T.vlen_create(tid);
                    else
                        obj.h5type_id = tid;
                    end
            end
        end
        
        function fn_handle = matlab_type(obj)
        % Return the MATLAB constructor associated with the ESCDF datatype.
        %
        % Returns
        % -------
        % fn_handle : function_handle or missing
        %     MATLAB constructor or conversion function associated with the
        %     property's datatype.
            switch lower(obj.format)
                case 'i1'
                    fn_handle = @int8;
                case 'i2'
                    fn_handle = @int16;
                case 'i4'
                    fn_handle = @int32;
                case 'i8'
                    fn_handle = @int64;
                case 'u1'
                    fn_handle = @uint8;
                case 'u2'
                    fn_handle = @uint16;
                case 'u4'
                    fn_handle = @uint32;
                case 'u8'
                    fn_handle = @uint64;
                case 'f4'
                    fn_handle = @single;
                case 'f8'
                    fn_handle = @double;
                case 'c8'
                    fn_handle = @single;
                case 'c16'
                    fn_handle = @double;
                case 'bytes'
                    fn_handle = @uint8;
                case 'str'
                    fn_handle = @num2str;
                otherwise
                    fn_handle = missing;
            end
        end
    end

    methods (Static)
        function out = check_hdf5_dataset(id)
            id_type = H5I.get_type(id);
            try
                out = H5ML.get_constant_value('H5I_DATASET') == id_type;
            catch
                out = false;
            end
        end

        function out = check_hdf5_group(id)
            id_type = H5I.get_type(id);
            try
                out = H5ML.get_constant_value('H5I_GROUP') == id_type;
            catch
                out = false;
            end
        end

        function obj = load(hdf5_path_or_id,readonly)
        % Load a property from an HDF5 dataset.
        %
        % Parameters
        % ----------
        % hdf5_path_or_id : char, string, or numeric
        %     HDF5 dataset path descriptor or open dataset identifier.
        % readonly : logical, optional
        %     If true, open read-only. If false, open read/write.
        %
        % Returns
        % -------
        % obj : escdf_property
        %     Loaded property.
        %
        % Raises
        % ------
        % error
        %     Raised if the requested object is not an HDF5 dataset or if
        %     the path specification is invalid.
            if nargin == 1
                readonly = true;
            end
            if isstring(hdf5_path_or_id)
                hdf5_path_or_id = char(hdf5_path_or_id);
            end
            if ischar(hdf5_path_or_id)
                file_parts = strsplit(hdf5_path_or_id,':');
                if length(file_parts) ~= 2
                    error('If hdf5_path_or_id is a string, it should contain the file path and the internal dataset path separated by a colon.')
                end
                file_path = file_parts{1};
                internal_path = file_parts{2};
                if readonly
                    read_flag = 'H5F_ACC_RDONLY';
                else
                    read_flag = 'H5F_ACC_RDWR';
                end
                file_id = H5F.open(file_path,read_flag,'H5P_DEFAULT');
                dataset_id = H5D.open(file_id, internal_path);
            else
                dataset_id = hdf5_path_or_id;
                if ~escdf_property.check_hdf5_dataset(dataset_id)
                    error(['ID ',num2str(dataset_id),' is not a valid HDF5 dataset identifier returned from H5D.open'])
                end
            end
            name_parts = strsplit(H5I.get_name(dataset_id),'/');
            name = name_parts{end};
            if escdf_property.VERBOSE
                disp(['Property Name: ',name])
            end
            data_type_attribute_id = H5A.open(dataset_id,'data_type');
            str_type_id = H5A.get_type(data_type_attribute_id);
            data_type = H5A.read(data_type_attribute_id,str_type_id);
            if iscell(data_type)
                data_type = data_type{1};
            end
            if escdf_property.VERBOSE
                disp(['Type of the Property: ',data_type])
            end
            H5A.close(data_type_attribute_id);
            H5T.close(str_type_id);
            space_id = H5D.get_space(dataset_id);
            [~, dims] = H5S.get_simple_extent_dims(space_id);
            H5S.close(space_id);
            if escdf_property.VERBOSE
                disp(['Dimensions of the Property: (',num2str(dims),')']);
            end
            % Need to check if it's a ragged array
            datatype_id = H5D.get_type(dataset_id);
            if H5T.get_class(datatype_id) == H5ML.get_constant_value('H5T_VLEN')
                if H5T.is_variable_str(datatype_id)
                    if escdf_property.VERBOSE
                        disp([name ' is a variable-length string dataset.']);
                    end
                    ragged = false;
                else
                    if escdf_property.VERBOSE
                        disp([name ' is a variable-length numeric dataset.']);
                    end
                    if strcmpi(data_type,'bytes')
                        if escdf_property.VERBOSE
                            disp('  However, it is a bytes object so we do not treat it as ragged.')
                        end
                        ragged = false;
                    else
                        ragged = true;
                    end
                end
            else
                if escdf_property.VERBOSE
                    disp([name ' is not a variable-length dataset.']);
                end
                ragged = false;
            end
            % Now create the dataset
            obj = escdf_property(name,data_type,dims,'ragged',ragged);
            obj.inmemory = false;
            obj.h5d_id = dataset_id;
            obj.backing_state = 'hdf5_native';
        end
    end
end

function is_data_missing = check_if_missing(data)
    % Had to add this because old versions of Matlab don't 
    try
        is_data_missing = ismissing(data);
    catch ME
        if strcmp(ME.identifier, 'MATLAB:ismissing:FirstInputInvalid')
            is_data_missing = false;
        else
            error(ME.message)
        end
    end
end