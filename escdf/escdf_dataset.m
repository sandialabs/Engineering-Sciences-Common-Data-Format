classdef escdf_dataset < handle & dynamicprops
% ESCDF_DATASET Specification-driven ESCDF dataset.
%
% An escdf_dataset represents one typed dataset defined by an ESCDF
% specification. Dataset properties are created dynamically from the
% parsed specification files and validated against the declared data
% types, shapes, optionality rules, enumerations, and choice groups.
%
% Parameters
% ----------
% name : char
%     Short dataset identifier used as the on-disk group name.
% dataset_type : char
%     Name of the ESCDF specification used to define the dataset.
% descriptive_name : char, optional
%     Human-readable dataset description.
% replace_invalid_names : logical, optional
%     If true, invalid dataset names are repaired automatically. If false,
%     invalid names raise an exception.
%
% Notes
% -----
% Most user-facing metadata and result datasets are instances of this
% class. The allowed properties are determined entirely by the selected
% specification.
%
% Datasets inheriting from parameter_set may also support notes,
% attachments, and attachment_names.
%
% See Also
% --------
% escdf_property
% escdf
% escdf_activity

    properties (Constant, Access=private)
        VERBOSE=false;
    end

    properties (Access=private)
        dataset_type;
        name;
        descriptive_name;
        has_modified_properties;
        has_pending_changes;
        backing_state;
        version;
    end

    methods
        function obj = escdf_dataset(name,dataset_type,descriptive_name, replace_invalid_names)
        % Create a specification-driven ESCDF dataset.
        %
        % Parameters
        % ----------
        % name : char
        %     Short dataset identifier used as the on-disk group name.
        % dataset_type : char
        %     Name of the ESCDF specification used to define the dataset.
        % descriptive_name : char, optional
        %     Human-readable dataset description.
        % replace_invalid_names : logical, optional
        %     If true, invalid dataset names are repaired automatically.
        %
        % Raises
        % ------
        % error
        %     Raised if the dataset name is invalid and
        %     replace_invalid_names is false.
            if nargin < 3
                descriptive_name = '';
            end
            if nargin < 4
                replace_invalid_names = false;
            end
            % Check if name is valid
            name_valid = escdf.is_valid_identifier(name);
            if (~name_valid) && replace_invalid_names
                name = escdf.make_valid_identifier(name, 'dataset_');
            elseif (~name_valid) && ~replace_invalid_names
                error('Invalid Name %s.  Names must start with a letter and consist of only letters, numbers, and underscores.', name)
            end
            obj.has_modified_properties = false;
            obj.has_pending_changes = false;
            obj.backing_state = 'memory';
            obj.name = name;
            obj.dataset_type = dataset_type;
            obj.descriptive_name = descriptive_name;

            registry = escdf_dataset.specification_cache_state('get');
            if isempty(registry)
                escdf_dataset.reload_specification_cache();
                registry = escdf_dataset.specification_cache_state('get');
            end

            resolved_specification = registry.resolve(dataset_type);
            obj.version = resolved_specification.version.as_array();

            property_names = resolved_specification.property_names;
            for i = 1:length(property_names)
                property_name = property_names{i};

                % In order to add custom setters, we add two dynamic
                % properties.  The DO_NOT_USE one is actually used to store
                % the data.  The other one is the user facing one that that
                % user will interact with.  The setters will store the data
                % into the hidden variable, and the getters will retrieve
                % it.

                current_properties = properties(obj);
                if ~ismember(property_name, current_properties)
                    hidden_prop = addprop(obj, ['DO_NOT_USE_', property_name]);
                    hidden_prop.Hidden = true;

                    % This is the property that the user will interact with.
                    user_prop = addprop(obj, property_name);
                    % We use custom setters to make sure that the data is in
                    % the right format.
                    user_prop.SetMethod = @(obj,val) escdf_dataset.set_dynamic_prop(property_name,obj,val);
                    user_prop.GetMethod = @(obj) escdf_dataset.get_dynamic_prop(property_name,obj);
                end
            end
        end

        function name = get_name(obj)
            name = obj.name;
        end

        function set_name(obj, new_name)
        % Set the dataset logical name.
        %
        % Parameters
        % ----------
        % new_name : char
        %     New dataset name.
            if ~(ischar(new_name) || isstring(new_name))
                error('New dataset name must be a string.');
            end
            new_name = char(string(new_name));

            if ~escdf.is_valid_identifier(new_name)
                error('New dataset name "%s" is not a valid identifier.', new_name);
            end

            obj.name = new_name;
            obj.has_pending_changes = true;
        end

        function name = get_descriptive_name(obj)
            name = obj.descriptive_name;
        end

        function version = get_version(obj)
            version = ['v',num2str(obj.version(1)),'.',num2str(obj.version(2)),'.',num2str(obj.version(3))];
        end

        function set_version(obj,major,minor,hotfix)
            obj.version = [major,minor,hotfix];
        end

        function version = get_version_numbers(obj)
            version = obj.version;
        end

        function out = get_has_modified_properties(obj)
        % Return whether the dataset contains modified or extra properties.
        %
        % Returns
        % -------
        % out : logical
        %     True if the dataset has modified or unknown properties that make it
        %     ineligible for normal valid write operations.
            out = obj.has_modified_properties;
        end

        function dimension_names = get_dimension_names(obj)
        % Return symbolic dimension names used by the dataset specification.
        %
        % Returns
        % -------
        % dimension_names : cell array of char
        %     Unique named dimensions referenced by the effective dataset
        %     specification.
            registry = escdf_dataset.specification_cache_state('get');
            if isempty(registry)
                escdf_dataset.reload_specification_cache();
                registry = escdf_dataset.specification_cache_state('get');
            end

            resolved_specification = registry.resolve(obj.get_type());
            dimension_names = resolved_specification.dimension_names;
        end

        function out = get_has_pending_changes(obj)
        % Return whether the dataset has pending changes.
        %
        % Returns
        % -------
        % out : logical
        %     True if the dataset has pending changes relative to its
        %     current authoritative/reference state.
            out = obj.has_pending_changes;
        end

        function out = get_backing_state(obj)
        % Return the dataset backing state.
        %
        % Returns
        % -------
        % out : char
        %     Dataset backing state.
            out = obj.backing_state;
        end

        function set_backing_state(obj, state)
        % Set the dataset backing state.
        %
        % Parameters
        % ----------
        % state : char
        %     Dataset backing state string.
            obj.backing_state = state;
        end

        function set_has_pending_changes(obj, tf)
        % Set the dataset pending-changes flag.
        %
        % Parameters
        % ----------
        % tf : logical
        %     Pending-changes state.
            obj.has_pending_changes = tf;
        end

        function out = validate(obj,hide_issues,report)
        % Validate dataset properties against the active specification.
        %
        % Parameters
        % ----------
        % hide_issues : logical, optional
        %     If true, suppress diagnostic messages describing validation
        %     failures.
        % report : logical, optional
        %     If true, return a structured ValidationReport instead of a
        %     logical validity flag.
        %
        % Returns
        % -------
        % out : logical or ValidationReport
        %     True if the dataset satisfies the specification and false
        %     otherwise when report is false. If report is true, return a
        %     structured ValidationReport.
            if nargin < 2
                hide_issues = false;
            end
            if nargin < 3
                report = false;
            end

            registry = escdf_dataset.specification_cache_state('get');

            if isempty(registry)
                escdf_dataset.reload_specification_cache();
                registry = escdf_dataset.specification_cache_state('get');
            end

            resolved_specification = registry.resolve(obj.dataset_type);
            validation_report = Validation.validate_dataset_against_resolved_specification( ...
                obj, resolved_specification, hide_issues);

            if report
                out = validation_report;
            else
                out = validation_report.is_valid;
            end
        end

        function disp(obj)
            fprintf('%s\n\n',obj.repr())
        end

        function out = repr(obj)
            if numel(obj) > 1
                out = [sprintf('\n  escdf_datasets: ')];
                for i = 1:length(obj)
                    dataset = obj(i);
                    property_list = sort(properties(dataset));
                    out = [out,sprintf('\n    '),dataset.get_name(),' (',dataset.get_type(),' ',dataset.get_version(),'):'];
                    out = [out,sprintf('\n      '),strjoin(property_list,', ')];
                end
            else
                property_list = sort(properties(obj));
                longest_length = max(cellfun(@length,property_list));
                string_format = ['%',num2str(longest_length+4),'s'];
                out = sprintf('\n  escdf_dataset: %s (%s %s)\n\n  Properties:\n',obj.name,obj.dataset_type, obj.get_version());
                for i = 1:length(property_list)
                    property_name = property_list{i};
                    property = obj.(property_name);
                    if isempty(property)
                        out = [out,sprintf('\n%s: %s',sprintf(string_format,property_name),'[]')];
                    else
                        if property.isinmemory()
                            memory_string = 'in memory';
                        else
                            memory_string = 'on disk';
                        end
                        string_parts = strsplit(property.repr(),[property_name,', ']);
                        repr_part = string_parts{end};
                        out = [out,sprintf('\n%s: %s, %s',sprintf(string_format,property_name),repr_part, memory_string)];
                    end
                end
                try
                    notes = obj.notes(:);
                    if ~isempty(notes)
                        out = [out,sprintf('\n\n  Notes:\n    '),strjoin(notes.',sprintf('\n    '))];
                    end
                end
                try
                    attachments = obj.attachment_names(:);
                    if ~isempty(attachments)
                        out = [out,sprintf('\n\n  Attachments:\n    '),strjoin(attachments.',sprintf('\n    '))];
                    end
                end
            end
        end

        function read_into_memory(obj)
        % Load all dataset properties into memory.
        %
        % Notes
        % -----
        % Properties already stored in memory are left unchanged.
        % Properties currently backed by HDF5 datasets are read fully into
        % in-memory property objects.
            property_list = properties(obj);
            for i = 1:length(property_list)
                property_name = property_list{i};
                property = obj.(property_name);
                if isa(property,'escdf_property')
                    property.read_into_memory();
                end
            end
            obj.backing_state = 'memory';
        end

        function write_to_disk(obj,hdf5_group_id)
        % Write the dataset to an HDF5 group.
        %
        % Parameters
        % ----------
        % hdf5_group_id : numeric
        %     HDF5 group identifier representing the dataset group.
        %
        % Raises
        % ------
        % error
        %     Raised if the dataset fails validation and therefore cannot
        %     be written.
        %
        % Notes
        % -----
        % Dataset properties are written as datasets within the target
        % group. The group also receives specification metadata attributes
        % such as _specification_name, _descriptive_name, and _version.
            isvalid = obj.validate();
            if ~isvalid
                error(['Incomplete escdf_dataset ',obj.name,' (',obj.dataset_type,') cannot be written to a file.'])
            end
            property_names = properties(obj);
            for i = 1:length(property_names)
                property = obj.(property_names{i});
                if isempty(property)
                    continue
                end
                if ~property.isinmemory()
                    warning('Overwriting HDF5 datasets is currently not implemented, so on-disk datasets are currently read into memory then rewritten to disk.  This could have implications for large datasets that will not fit into memory.')
                    property.read_into_memory()
                end
                property.write_to_disk(hdf5_group_id);
            end
            attr_space_id = H5S.create('H5S_SCALAR');
            str_type_id = H5T.copy('H5T_C_S1');
            H5T.set_size(str_type_id, 'H5T_VARIABLE');
            attr_id = H5A.create(hdf5_group_id, '_specification_name', str_type_id, attr_space_id, 'H5P_DEFAULT');
            H5A.write(attr_id,str_type_id,obj.dataset_type);
            attr_id = H5A.create(hdf5_group_id, '_descriptive_name', str_type_id, attr_space_id, 'H5P_DEFAULT');
            H5A.write(attr_id,str_type_id,obj.descriptive_name);
            % Create the attribute
            attr_type = H5T.copy('H5T_NATIVE_INT'); % Use H5T_NATIVE_INT if you want integers
            attr_space = H5S.create_simple(1, numel(obj.version), []);
            attr_id = H5A.create(hdf5_group_id, '_version', attr_type, attr_space, 'H5P_DEFAULT', 'H5P_DEFAULT');
            % Write the attribute data
            H5A.write(attr_id, attr_type, int32(obj.version));
            H5A.close(attr_id);
            H5T.close(str_type_id);
            H5S.close(attr_space_id);
            obj.backing_state = 'hdf5_native';
            obj.has_pending_changes = false;
        end

        function help(obj)
        % Display specification documentation for this dataset type.
        %
        % Notes
        % -----
        % Documentation is sourced from the canonical local specification.
            registry = escdf_dataset.specification_cache_state('get');
            if isempty(registry)
                escdf_dataset.reload_specification_cache();
                registry = escdf_dataset.specification_cache_state('get');
            end

            local_specification = registry.get_local(obj.dataset_type);
            disp(local_specification.documentation)
            disp(local_specification.notes)
        end

        function delete(obj)
            if escdf_dataset.VERBOSE
                disp(['Destructor called for dataset ',obj.name])
            end
        end

        function type = get_type(obj)
        % Return the dataset specification type.
        %
        % Returns
        % -------
        % type : char
        %     Dataset specification name.
            type = obj.dataset_type;
        end

        function supertype_list = get_supertypes(obj)
        % Return the dataset specification inheritance chain.
        %
        % Returns
        % -------
        % supertype_list : cell array of char
        %     Ordered list of specification names in canonical inheritance
        %     application order, beginning with the root ancestor and
        %     ending with this dataset type.
            registry = escdf_dataset.specification_cache_state('get');
            if isempty(registry)
                escdf_dataset.reload_specification_cache();
                registry = escdf_dataset.specification_cache_state('get');
            end

            resolved_specification = registry.resolve(obj.get_type());
            supertype_list = resolved_specification.ancestry;
        end

        function out = istype(obj,type)
        % Check whether the dataset inherits from a specification type.
        %
        % Parameters
        % ----------
        % type : char
        %     Specification type name to test.
        %
        % Returns
        % -------
        % out : logical
        %     True if the dataset is of the requested type or inherits from
        %     it, otherwise false.
            parent_list = obj.get_supertypes();
            if any(strcmp(parent_list,type))
                out=true;
            else
                out=false;
            end
        end

        function set_attachments(obj,filenames)
        % Read files from disk and store them as dataset attachments.
        %
        % Parameters
        % ----------
        % filenames : char or cell array of char
        %     File path or collection of file paths to attach.
        %
        % Notes
        % -----
        % Only the basename of each file is stored in attachment_names.
        % File contents are stored in attachments as byte arrays.
            if ischar(filenames)
                filenames = {filenames};
            end
            attachment_names = {};
            attachments = {};
            for i = 1:length(filenames)
                filename = filenames{i};
                [~,fname,fext] = fileparts(filename);
                attachment_name = [fname,fext];
                fid = fopen(filename,'r');
                attachment = fread(fid);
                fclose(fid);
                attachments{end+1} = uint8(attachment);
                attachment_names{end+1} = attachment_name;
            end
            obj.attachments = attachments(:);
            obj.attachment_names = attachment_names(:);
        end

        function dump_attachments_to_disk(obj,file_path)
        % Write stored attachments to files on disk.
        %
        % Parameters
        % ----------
        % file_path : char, optional
        %     Output directory for extracted attachments.
        %
        % Raises
        % ------
        % error
        %     Raised if the dataset does not contain attachment properties.
            if nargin < 2
                file_path = '';
            end
            try
                attachment_names = obj.attachment_names(:);
                attachments = obj.attachments(:);
            catch
                error('No attachments properties found.  Could not write attachments to disk')
            end
            for i = 1:length(attachment_names)
                attachment_name = attachment_names{i};
                attachment = attachments{i};
                fid = fopen(fullfile(file_path,attachment_name),'w');
                fwrite(fid,attachment);
                fclose(fid);
            end
        end

        function table_out = dump_to_table(obj,dimension_name,max_columns)
        % Convert selected dataset properties to a table.
        %
        % Parameters
        % ----------
        % dimension_name : char
        %     Dimension name used to identify which properties should be
        %     expanded into table columns.
        % max_columns : numeric, optional
        %     Maximum number of derived columns to include from any one
        %     property.
        %
        % Returns
        % -------
        % table_out : table
        %     Tabular representation of selected dataset properties.
            if nargin < 3
                max_columns = 10;
            end

            registry = escdf_dataset.specification_cache_state('get');
            if isempty(registry)
                escdf_dataset.reload_specification_cache();
                registry = escdf_dataset.specification_cache_state('get');
            end

            resolved_specification = registry.resolve(obj.get_type());

            % Build a mapping from property name to a unique compatible
            % canonical definition that includes the requested dimension.
            compatible_dimension_info = {};

            property_names = resolved_specification.property_names;
            for i = 1:length(property_names)
                property_name = property_names{i};
                property = obj.(property_name);
                if isempty(property)
                    continue
                end

                property_definitions = resolved_specification.properties_by_name(property_name);

                matching_definitions = {};
                for j = 1:length(property_definitions)
                    property_definition = property_definitions(j);
                    shape = property_definition.shape;

                    dimension_matches = false(1, length(shape));
                    for k = 1:length(shape)
                        dim = shape(k);
                        if dim.is_symbolic() && strcmp(dim.value, dimension_name)
                            dimension_matches(k) = true;
                        end
                    end

                    if ~any(dimension_matches)
                        continue
                    end

                    if ~escdf_dataset.check_if_property_is_acceptable(property_definition, property)
                        continue
                    end

                    matching_definitions{end+1} = {property_definition, dimension_matches}; %#ok<AGROW>
                end

                if length(matching_definitions) == 1
                    compatible_dimension_info{end+1} = ...
                        {property_name, matching_definitions{1}{1}, matching_definitions{1}{2}}; %#ok<AGROW>
                end
            end

            column_names = {};
            data_array = {};

            for i = 1:length(compatible_dimension_info)
                property_name = compatible_dimension_info{i}{1};
                property_definition = compatible_dimension_info{i}{2};
                dimension_matches = compatible_dimension_info{i}{3};

                property = obj.(property_name);
                full_data = property(:);

                matched_dimension_index = find(dimension_matches, 1);
                full_shape = size(full_data);

                % Ensure full_shape has as many entries as canonical rank
                if length(full_shape) < length(property_definition.shape)
                    full_shape = [full_shape, ones(1, length(property_definition.shape) - length(full_shape))];
                end

                unmatched_dimension_indices = setdiff(1:length(property_definition.shape), matched_dimension_index);

                if isempty(unmatched_dimension_indices)
                    % Scalar/vector case where the requested dimension is the
                    % only dimension.
                    slice_indices = repmat({':'}, 1, length(property_definition.shape));
                    slice = full_data(slice_indices{:});
                    data_array{end+1} = slice(:); %#ok<AGROW>

                    index_string = repmat({''}, 1, length(property_definition.shape));
                    index_string{matched_dimension_index} = ':';
                    column_name = [property_name, '(', strjoin(index_string, ','), ')'];
                    column_names{end+1} = column_name; %#ok<AGROW>
                    continue
                end

                remaining_sizes = full_shape(unmatched_dimension_indices);
                n_remaining = prod(remaining_sizes);

                for j = 1:n_remaining
                    fixed_index_values = cell(1, numel(unmatched_dimension_indices));

                    if numel(remaining_sizes) == 1
                        fixed_index_values{1} = j;
                    else
                        [fixed_index_values{:}] = ind2sub(remaining_sizes, j);
                    end

                    slice_indices = cell(1, length(property_definition.shape));
                    for k = 1:length(slice_indices)
                        slice_indices{k} = 1;
                    end
                    slice_indices{matched_dimension_index} = ':';
                    for k = 1:numel(unmatched_dimension_indices)
                        slice_indices{unmatched_dimension_indices(k)} = fixed_index_values{k};
                    end

                    slice = full_data(slice_indices{:});
                    data_array{end+1} = slice(:); %#ok<AGROW>

                    index_string = cell(1, length(property_definition.shape));
                    for k = 1:length(index_string)
                        index_string{k} = '';
                    end
                    index_string{matched_dimension_index} = ':';
                    for k = 1:numel(unmatched_dimension_indices)
                        index_string{unmatched_dimension_indices(k)} = num2str(fixed_index_values{k});
                    end

                    column_name = [property_name, '(', strjoin(index_string, ','), ')'];
                    column_names{end+1} = column_name; %#ok<AGROW>

                    if j >= max_columns
                        break
                    end
                end
            end

            if isempty(data_array)
                table_out = table();
                return
            end

            lengths = cellfun(@length, data_array);
            most_common_length = mode(lengths);
            inds_to_keep = lengths == most_common_length;

            column_names = column_names(inds_to_keep);
            data_array = data_array(inds_to_keep);

            table_out = table(data_array{:}, 'VariableNames', column_names);
        end

        function out = dump_to_struct(obj)
        % Convert the dataset to a plain MATLAB struct.
        %
        % Returns
        % -------
        % out : struct
        %     Struct containing dataset properties and ESCDF metadata
        %     fields.
            out = struct();
            metadata_properties = properties(obj);
            for j = 1:length(metadata_properties)
                this_property_name = metadata_properties{j};
                this_property = obj.(this_property_name);
                if isempty(this_property)
                    out.(this_property_name) = [];
                else
                    out.(this_property_name) = this_property(:);
                end
            end
            out.ESCDF_DATASET_TYPE = obj.get_type();
            out.ESCDF_DESCRIPTIVE_NAME = obj.descriptive_name;
        end
    end
    methods (Access = public, Static)

        function reload_specification_cache()
        % Reset specification state back to the packaged ESCDF defaults.
        %
        % Notes
        % -----
        % This discards any appended specification directories and rebuilds
        % the persistent canonical specification registry from the packaged
        % ESCDF specification directory only.
            registry = SpecificationRegistry.build_default_registry();
            escdf_dataset.specification_cache_state('set', registry);
        end

        function load_specification_directory(directory)
        % Append specification files from an additional directory to the
        % cached specification registry.
        %
        % Parameters
        % ----------
        % directory : char
        %     Directory containing additional ESCDF specification files.
        %
        % Notes
        % -----
        % This method is primarily intended for tests or specialized
        % workflows that need to extend the active specification set
        % without modifying the packaged ESCDF specifications.
            if ~(ischar(directory) || isstring(directory))
                error('directory must be a string.');
            end
            directory = char(string(directory));

            registry = escdf_dataset.specification_cache_state('get');

            if isempty(registry)
                registry = SpecificationRegistry.build_default_registry();
            end

            registry.load_from_directory(directory);
            escdf_dataset.specification_cache_state('set', registry);
        end

        function registry_cache = specification_cache_state(action, varargin)
        % Manage shared cached canonical specification registry state.
        %
        % Parameters
        % ----------
        % action : char
        %     Cache action. Supported values are:
        %     - 'get'
        %     - 'set'
        %     - 'clear'
        %
        % Returns
        % -------
        % registry_cache : SpecificationRegistry or []
        %     Cached canonical specification registry.
            persistent cached_registry

            if nargin < 1
                action = 'get';
            end

            switch lower(action)
                case 'get'
                    % no-op, just return current value

                case 'set'
                    cached_registry = varargin{1};

                case 'clear'
                    cached_registry = [];

                otherwise
                    error('Unknown specification cache action "%s".', action);
            end

            registry_cache = cached_registry;
        end

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

        function out = check_hdf5_file(id)
            id_type = H5I.get_type(id);
            try
                out = H5ML.get_constant_value('H5I_FILE') == id_type;
            catch
                out = false;
            end
        end

        function isacceptable = check_if_property_is_acceptable(acceptable_property_definitions, property)
        % Return whether a property matches one of the acceptable canonical
        % property definitions.
        %
        % Parameters
        % ----------
        % acceptable_property_definitions : PropertyDefinition array
        %     Canonical candidate property definitions.
        % property : escdf_property
        %     Property to check.
        %
        % Returns
        % -------
        % isacceptable : logical
        %     True if the property matches at least one acceptable
        %     canonical property definition.
            isacceptable = false;
            for i = 1:length(acceptable_property_definitions)
                property_definition = acceptable_property_definitions(i);

                % Check that the names are the same
                if ~strcmp(property_definition.name, property.get_name())
                    continue
                end

                % Check if the formats are the same
                if ~strcmp(property_definition.datatype, property.get_format())
                    continue
                end

                % Check ragged setting
                if property_definition.variable_length ~= property.isragged()
                    continue
                end

                % Check if the sizes are the same (or at least consistent)
                actual_size = property.get_size();
                shape = property_definition.shape;

                if length(shape) ~= length(actual_size)
                    continue
                end

                all_sizes_match = true;
                for j = 1:length(shape)
                    dimension_definition = shape(j);
                    if dimension_definition.is_symbolic()
                        continue
                    else
                        if dimension_definition.value ~= actual_size(j)
                            all_sizes_match = false;
                            break
                        end
                    end
                end

                if ~all_sizes_match
                    continue
                end

                % If we get to this point, then we match all parameters.
                isacceptable = true;
                break
            end
        end

        function property = build_property_from_array(name, acceptable_property_definitions, array)
        % Build an escdf_property from array-like input using canonical
        % property-definition candidates.
        %
        % Parameters
        % ----------
        % name : char
        %     Property name.
        % acceptable_property_definitions : PropertyDefinition array
        %     Canonical candidate property definitions for this property.
        % array : array-like
        %     Input data to convert into an escdf_property.
        %
        % Returns
        % -------
        % property : escdf_property
        %     Property object matching the best acceptable canonical
        %     definition.
        %
        % Raises
        % ------
        % error
        %     Raised if no acceptable property can be constructed from the
        %     supplied data.
            preferred_type_order = {'u1','u2','u4','u8','i1','i2','i4','i8', ...
                'f4','f8','c8','c16','str','bytes'};

            all_properties = {};
            dimension_scores = [];
            type_scores = [];

            for j = 1:length(acceptable_property_definitions)
                property_definition = acceptable_property_definitions(j);

                sizes = [];
                shape = property_definition.shape;

                if isempty(shape)
                    size_name = 'scalar';
                else
                    size_name = strjoin(arrayfun(@char, shape, 'UniformOutput', false), ',');
                    for i = 1:length(shape)
                        dimension_definition = shape(i);
                        if dimension_definition.is_fixed()
                            sizes(end+1) = dimension_definition.value; %#ok<AGROW>
                        else
                            data_size = size(array);
                            if i > length(data_size)
                                sizes(end+1) = 1; %#ok<AGROW>
                            else
                                sizes(end+1) = data_size(i); %#ok<AGROW>
                            end
                        end
                    end
                end

                if escdf_dataset.VERBOSE
                    disp(['Name: ',name])
                    disp(['Type: ',property_definition.datatype])
                    disp(['Size: ',size_name,' (',num2str(sizes),')'])
                    disp(['Optional: ',num2str(property_definition.optional)])
                    disp(['Variable Length: ',num2str(property_definition.variable_length)])
                end

                property = escdf_property( ...
                    name, ...
                    property_definition.datatype, ...
                    sizes, ...
                    'ragged', property_definition.variable_length);

                try
                    property(:) = array;
                catch
                    continue
                end

                if isequal(property.get_data(), array) || (length(acceptable_property_definitions) == 1)
                    all_properties{end+1} = property; %#ok<AGROW>
                    dimension_scores(end+1) = length(property.get_size()); %#ok<AGROW>
                    type_scores(end+1) = find(strcmp(preferred_type_order, property.get_format())); %#ok<AGROW>
                end
            end

            if isempty(all_properties)
                error(['Could not build a escdf_property ',name,' to match the requested specifications.'])
            end

            [~, min_index] = min(dimension_scores + type_scores * 10);
            property = all_properties{min_index};
        end

        function set_dynamic_prop(name,obj,val)
            if escdf_dataset.VERBOSE
                disp(['Setting ',name])
            end
            % Here we need to construct a property object if necessary
            % Otherwise we need to do some checks to make sure the property
            % object is the right size/shape.
            % Things that could be assigned to a property:
            %  1. An already existing property object
            %  2. A file path or dataset ID that we can load into a
            %     property object
            %  3. An array (cell array or regular array) that we need to
            %     turn into a property object.
            %  4. An empty array to say we aren't using that property.
            % There are also two things that could happen with the name.
            %  1. It could be a name that always exists or is optional.  In
            %     this case, the correct specification should be trivial to
            %     find.
            %  2. It could be a name that conditionally exists as part of a
            %     choice specified by the "or" option in the specification
            %     file.  In this case, we will need to dig through the
            %     options to find the correct specification (or a matching
            %     one).
            if isequal(val,[])
                obj.(['DO_NOT_USE_',name]) = [];
                return
            end
            % Find all canonical property-definition candidates for this
            % property name.
            property_definitions = escdf_dataset.get_candidate_property_definitions( ...
                obj.dataset_type, name);

            if isempty(property_definitions)
                current_properties = properties(obj);
                if ~ismember(name, current_properties)
                    error(['Assigned property ',name,' is not a valid property name for dataset type ',obj.dataset_type])
                end
            end

            if isa(val,'escdf_property')
                % This is already a property object, so we just need to see
                % if it has the right name, format, and shape, then we can
                % accept it.
                this_property = val;
            else
                % This could be a file path, or it could be a numerical
                % identifier for an HDF5 dataset.  So we will simply try to
                % load it, and if it fails, then it must be a regular
                % array type object.
                try
                    if numel(val) > 1
                        error('Kick to catch because an identifier is a single number')
                    elseif val > 1.224979098644775e+18 && val < 9.223372036854776e+18
                        error('Somehow these values cause HDF5 to crash, so kick to the catch block to avoid a crash')
                    end
                    this_property = escdf_property.load(val);
                catch
                    % If it fails, then that means that we have to
                    % construct a property from an array.
                    this_property = escdf_dataset.build_property_from_array(name, property_definitions, val);
                end
            end
            if ~isempty(property_definitions)
                if ~escdf_dataset.check_if_property_is_acceptable(property_definitions, this_property)
                    error(['Assigned property is not consistent with the specification for ',name])
                end
            end
            obj.(['DO_NOT_USE_',name]) = this_property;
            obj.has_pending_changes = true;
        end

        function val = get_dynamic_prop(name,obj)
            if escdf_dataset.VERBOSE
                disp(['Getting ',name])
            end
            val = obj.(['DO_NOT_USE_',name]);
        end

        function array_out = moveaxis(array_in, dim, to)
            % Validate inputs
            if dim == to
                array_out = array_in;
                return;
            end
            % Get the number of dimensions in the input array
            ndimsin = ndims(array_in);
            % Create the new order of dimensions
            order = 1:ndimsin;
            order(dim) = [];
            order = [order(1:to-1), dim, order(to:end)];
            % Permute the array
            array_out = permute(array_in, order);
        end
    end

    methods (Static)
        function obj = load(hdf5_path_or_id,readonly)
        % Load a dataset from an HDF5 group.
        %
        % Parameters
        % ----------
        % hdf5_path_or_id : char, string, or numeric
        %     HDF5 dataset path descriptor or open group identifier.
        % readonly : logical, optional
        %     If true, open read-only. If false, open read/write.
        %
        % Returns
        % -------
        % obj : escdf_dataset
        %     Loaded dataset.
        %
        % Notes
        % -----
        % Unknown dataset types are mapped to the unknown specification.
        % Extra on-disk properties that are not defined in the
        % specification are preserved and marked as modified.
            if nargin == 1
                readonly = true;
            end
            if isstring(hdf5_path_or_id)
                hdf5_path_or_id = char(hdf5_path_or_id);
            end
            if ischar(hdf5_path_or_id)
                file_parts = strsplit(hdf5_path_or_id,'::');
                if length(file_parts) ~= 2
                    error('If hdf5_path_or_id is a string, it should contain the file path and the internal group path separated by a double-colon (::).')
                end
                file_path = file_parts{1};
                internal_path = file_parts{2};
                if readonly
                    read_flag = 'H5F_ACC_RDONLY';
                else
                    read_flag = 'H5F_ACC_RDWR';
                end
                file_id = H5F.open(file_path,read_flag,'H5P_DEFAULT');
                group_id = H5G.open(file_id, internal_path);
            else
                group_id = hdf5_path_or_id;
                if ~escdf_dataset.check_hdf5_group(group_id)
                    error(['ID ',num2str(group_id),' is not a valid HDF5 group identifier returned from H5D.open'])
                end
            end
            name_parts = strsplit(H5I.get_name(group_id),'/');
            name = name_parts{end};
            if escdf_dataset.VERBOSE
                disp(['Dataset Name: ',name])
            end
            data_type_attribute_id = H5A.open(group_id,'_specification_name');
            str_type_id = H5A.get_type(data_type_attribute_id);
            data_type = H5A.read(data_type_attribute_id,str_type_id);
            if iscell(data_type)
                data_type = data_type{1};
            end
            if escdf_dataset.VERBOSE
                disp(['Type of the Group: ',data_type])
            end
            % Make sure that it is a known type.
            registry = escdf_dataset.specification_cache_state('get');
            if isempty(registry)
                escdf_dataset.reload_specification_cache();
                registry = escdf_dataset.specification_cache_state('get');
            end

            if ~registry.has_local(data_type)
                warning(sprintf('Dataset %s has an undefined type %s and will be written to an unknown dataset.',name,data_type))
                original_data_type = data_type;
                data_type = 'unknown';
            else
                original_data_type = [];
            end
            try
                descriptive_name_attribute_id = H5A.open(group_id,'_descriptive_name');
                str_type_id = H5A.get_type(descriptive_name_attribute_id);
                descriptive_name = H5A.read(descriptive_name_attribute_id,str_type_id);
            catch
                descriptive_name = name;
            end
            try % Version Number
                version_attribute_id = H5A.open(group_id, '_version');
                % Get the datatype and dataspace of the attribute
                version_attr_type = H5A.get_type(version_attribute_id);

                % Read the attribute data
                version_numbers = H5A.read(version_attribute_id, version_attr_type);
                if length(version_numbers) ~= 3
                    error('Malformed version numbers for dataset %s with type %s',name,data_type)
                end
            catch
                warning('Unable to read version numbers for dataset %s with type %s',name,data_type)
                version_numbers = [0,0,0];
            end
            obj = escdf_dataset(name,data_type,descriptive_name,true);
            current_version_numbers = obj.get_version_numbers();
            if ~all(int32(version_numbers(:)) == int32(current_version_numbers(:)))
                warning('Version number of %s dataset in loaded file (v%s) is not the version in the current ESCDF implementation (v%s)', data_type, strjoin(arrayfun(@num2str, version_numbers, 'UniformOutput', false), '.'), strjoin(arrayfun(@num2str, current_version_numbers, 'UniformOutput', false), '.'));
                obj.set_version(version_numbers(1),version_numbers(2),version_numbers(3))
            end
            if obj.istype('unknown')
                obj.original_type_name = {original_data_type};
            end
            property_names = properties(obj);
            for i = 1:length(property_names)
                property_name = property_names{i};
                try
                    dataset_id = H5D.open(group_id,property_name);
                catch
                    continue
                end
                obj.(property_name) = dataset_id;
            end
            % For backwards compatibility, check if there are any names
            % that haven't been read yet
            all_datasets = escdf_dataset.get_group_datasets(group_id);
            extra_datasets = setdiff(all_datasets,property_names);
            for i = 1:length(extra_datasets)
                extra_dataset = extra_datasets{i};
                warning(sprintf('When loading dataset %s, an unknown extra property %s was found that was not defined in the specification.',...
                    name,extra_dataset));
                obj.has_modified_properties = true;
                dataset_id = H5D.open(group_id,extra_dataset);
                prop = escdf_property.load(dataset_id);
                addprop(obj,extra_dataset);
                obj.(extra_dataset) = prop;
            end
            obj.backing_state = 'hdf5_native';
            obj.has_pending_changes = false;
        end

        function datasets = get_group_datasets(group_id)
            % Initialize output variables
            datasets = {};
            % Get the number of objects in the group
            info = H5G.get_info(group_id);
            numObjs = info.nlinks;
            % Iterate over the objects in the group
            for idx = 0:numObjs-1
                % Get the name of the object
                objName = H5G.get_objname_by_idx(group_id, idx);
                % Get the type of the object
                objType = H5G.get_objtype_by_idx(group_id, idx);
                % Check the type and add to the appropriate list
                if objType == H5ML.get_constant_value('H5G_DATASET')
                    datasets{end+1} = objName; %#ok<AGROW>
                end
            end
        end
        function obj = build_from_struct(name,structure)
        % Build a dataset from a plain MATLAB struct.
        %
        % Parameters
        % ----------
        % name : char
        %     Dataset name.
        % structure : struct
        %     Struct containing dataset properties and ESCDF metadata
        %     fields.
        %
        % Returns
        % -------
        % obj : escdf_dataset
        %     Constructed dataset.
            dataset_type = structure.ESCDF_DATASET_TYPE;
            obj = escdf_dataset(name,dataset_type,structure.ESCDF_DESCRIPTIVE_NAME);
            dataset_property_names = fields(structure);
            for i = 1:length(dataset_property_names)
                dataset_property_name = dataset_property_names{i};
                if strcmp(dataset_property_name,'ESCDF_DATASET_TYPE')
                    continue
                elseif strcmp(dataset_property_name,'ESCDF_DESCRIPTIVE_NAME')
                    continue
                end
                if ~isempty(structure.(dataset_property_name))
                    obj.(dataset_property_name) = structure.(dataset_property_name);
                end
            end
        end

        function obj = unflatten_data(flat_data_struct)
            obj = flat_data_struct; % Should be a copy of the structure
            data_dimension = size(flat_data_struct.channel,2);
            % Find unique entries in each column of labels
            unique_labels = cell(1, data_dimension);
            label_indices = cell(1, data_dimension);
            for col = 1:data_dimension
                [unique_labels{col}, ~, label_indices{col}] = unique(flat_data_struct.channel(:, col),'stable');
            end
            % Determine the size of the output data matrix
            output_size = [cellfun(@numel, unique_labels),size(flat_data_struct.ordinate,2)];
            % Initialize the output data matrix
            data_matrix = nan(output_size);
            % Convert label indices to linear indices for the data matrix
            linear_indices = sub2ind(output_size(1:end-1), label_indices{:});
            % Expand linear indices to match number of samples
            expanded_indices = repmat(linear_indices, 1, size(flat_data_struct.ordinate,2)) + ...
                (0:size(flat_data_struct.ordinate,2)-1) * prod(output_size(1:end-1));
            % Reshape data into a column vector for direct assignment
            data_vector = reshape(flat_data_struct.ordinate, [], 1);
            % Assign data values to the matrix using precomputed indices
            data_matrix(expanded_indices) = data_vector;
            % Assign it to the returned object
            obj.ordinate = data_matrix;
            % Check and see if we need to do the same thing to the
            % abscissa
            if ~isempty(flat_data_struct.abscissa) && isequal(size(flat_data_struct.abscissa),size(flat_data_struct.ordinate))
                data_matrix = nan(output_size);
                data_vector = reshape(flat_data_struct.abscissa, [], 1);
                data_matrix(expanded_indices) = data_vector;
                obj.abscissa = data_matrix;
            end
            % Now we need to handle the units
            for unit_label = {'abscissa_unit','ordinate_unit'}
                units = flat_data_struct.(unit_label{1});
                if ~isscalar(units)
                    data_matrix = cell(output_size(1:end-1));
                    data_matrix(linear_indices) = units;
                    obj.(unit_label{1}) = data_matrix;
                end
            end
            obj.channel = unique_labels;
        end

        function obj = flatten_data(unflat_data_struct)
            obj = unflat_data_struct; % Should be a copy of the structure
            ord_size = size(unflat_data_struct.ordinate);
            ord_elements = ord_size(end);
            data_size = ord_size(1:end-1);
            % Handle ordinate
            obj.ordinate = reshape(unflat_data_struct.ordinate,[],ord_elements);
            % Handle Abscissa
            if ~isempty(unflat_data_struct.abscissa)
                abs_size = size(unflat_data_struct.abscissa);
                if ~isequal(abs_size,ord_size) % If they aren't the same size, it has to be a vector
                    if sum(abs_size ~= 1) ~= 1 % Check if there is more than one non-singleton dimension
                        error('abscissa must either have the same size as ordinate or a single dimension')
                    elseif numel(unflat_data_struct.abscissa) ~= ord_elements % Check that it is the right length
                        error('abscissa must have the same number of elements as ordinate''s last dimension')
                    end
                    % Assign the vector as a column vector
                    obj.abscissa = unflat_data_struct.abscissa(:);
                else
                    % If it is the same size as the ordinate, we can just
                    % reshape it.
                    obj.abscissa = reshape(unflat_data_struct.abscissa,[],ord_elements);
                end
            end
            % Handle units
            for unit_label = {'abscissa_unit','ordinate_unit'}
                units = unflat_data_struct.(unit_label{1});
                if ~isscalar(units)
                    if ~isequal(data_size,size(units))
                        error('Units must either be a scalar or the same size as the ordinate field with the last dimension removed')
                    end
                    obj.(unit_label{1}) = units(:);
                end
            end
            % Handle channel names
            if ~isequal(numel(unflat_data_struct.channel),numel(data_size))
                error('channel field must have a cell array for each dimension of ordinate')
            end
            for i = 1:length(data_size)
                if data_size(i) ~= numel(unflat_data_struct.channel{i})
                    error('Dimension %i of ordinate has size %i but %i channel names are provided',i,data_size(i),data_size(i))
                end
            end
            out_channels = cell(numel(unflat_data_struct.channel),1);
            [out_channels{:}] = ndgrid(unflat_data_struct.channel{:});
            flat_channels = cellfun(@(x)reshape(x,[],1),out_channels,'UniformOutput',false);
            obj.channel = [flat_channels{:}];
        end
    end

    methods (Access=private, Static)
        function property_definitions = get_candidate_property_definitions(dataset_type, property_name)
        % Return canonical property-definition candidates for a property name.
        %
        % Parameters
        % ----------
        % dataset_type : char
        %     Dataset specification type.
        % property_name : char
        %     Property name to resolve.
        %
        % Returns
        % -------
        % property_definitions : PropertyDefinition array
        %     Canonical candidate property definitions for the requested
        %     name.
            registry = escdf_dataset.specification_cache_state('get');
            if isempty(registry)
                escdf_dataset.reload_specification_cache();
                registry = escdf_dataset.specification_cache_state('get');
            end

            resolved_specification = registry.resolve(dataset_type);

            if isKey(resolved_specification.properties_by_name, property_name)
                property_definitions = resolved_specification.properties_by_name(property_name);
            else
                property_definitions = PropertyDefinition.empty(1,0);
            end
        end
    end
end
