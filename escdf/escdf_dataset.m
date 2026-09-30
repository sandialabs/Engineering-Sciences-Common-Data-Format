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
            obj.name = name;
            obj.dataset_type = dataset_type;
            obj.descriptive_name = descriptive_name;
            [info, property_dictionary] = escdf_dataset.get_specification_info(dataset_type);
            obj.version = info{7};
            keyArray = keys(property_dictionary);
            for i = 1:length(keyArray)
                property_name = keyArray{i};
                % In order to add custom setters, we add two dynamic
                % properties.  The DO_NOT_USE one is actually used to store
                % the data.  The other one is the user facing one that that
                % user will interact with.  The setters will store the data
                % into the hidden variable, and the getters will retrieve
                % it.
                if isa(property_dictionary(property_name),'containers.Map')
                    options = property_dictionary(property_name);
                    option_names = keys(options);
                    for j = 1:length(option_names)
                        option_properties = options(option_names{j});
                        for k = 1:length(option_properties)
                            option_property_name = option_properties{k}{1};
                            current_properties = properties(obj);
                            if ~ismember(option_property_name,current_properties)
                                prop = addprop(obj,['DO_NOT_USE_',option_property_name]);
                                prop.Hidden = true;
                                % This is the property that the user will interact with.
                                prop = addprop(obj,option_property_name);
                                % We use custom setters to make sure that the data is in
                                % the right format.
                                prop.SetMethod = @(obj,val) escdf_dataset.set_dynamic_prop(option_property_name,obj,val);
                                prop.GetMethod = @(obj) escdf_dataset.get_dynamic_prop(option_property_name,obj);
                            end
                        end
                    end
                else
                    prop = addprop(obj,['DO_NOT_USE_',property_name]);
                    prop.Hidden = true;
                    % This is the property that the user will interact with.
                    prop = addprop(obj,property_name);
                    % We use custom setters to make sure that the data is in
                    % the right format.
                    prop.SetMethod = @(obj,val) escdf_dataset.set_dynamic_prop(property_name,obj,val);
                    prop.GetMethod = @(obj) escdf_dataset.get_dynamic_prop(property_name,obj);
                end
            end
        end

        function name = get_name(obj)
            name = obj.name;
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

        function valid_choices = find_valid_choice_specification(obj,choice_dictionary)
        % Identify valid choice branches for a specification choice group.
        %
        % Parameters
        % ----------
        % choice_dictionary : containers.Map
        %     Mapping from choice name to property-definition lists.
        %
        % Returns
        % -------
        % valid_choices : cell array of char
        %     Names of choice branches that validate successfully for the
        %     current dataset state.
            valid_choices = {};
            choices = keys(choice_dictionary);
            for i = 1:length(choices)
                if escdf_dataset.VERBOSE
                    disp(['Choice: ',choices{i}]);
                end
                property_dictionary = choice_dictionary(choices{i});
                isvalid = obj.validate(property_dictionary,true);
                if isvalid
                    valid_choices{end+1} = choices{i};
                end
            end
        end

        function isvalid = validate(obj,property_dictionary,hide_issues)
        % Validate dataset properties against the active specification.
        %
        % Parameters
        % ----------
        % property_dictionary : containers.Map or cell array, optional
        %     Alternate property definition mapping to validate against. If
        %     omitted, the dataset's declared specification is used.
        % hide_issues : logical, optional
        %     If true, suppress diagnostic messages describing validation
        %     failures.
        %
        % Returns
        % -------
        % isvalid : logical
        %     True if the dataset satisfies the specification and false
        %     otherwise.
        %
        % Notes
        % -----
        % Validation checks include:
        %
        % - presence of required properties
        % - datatype consistency
        % - shape and dimension consistency
        % - enumeration membership
        % - regular-expression conformance
        % - satisfaction of or: choice groups
        %
        % Datasets containing unknown extra properties loaded from disk are
        % considered invalid for normal write operations.
            if nargin == 1
                [property_data,property_dictionary] = escdf_dataset.get_specification_info(obj.dataset_type);
            else
                [property_data,~] = escdf_dataset.get_specification_info(obj.dataset_type);
            end
            if nargin < 3
                hide_issues = false;
            end
            % Make it flexible enough to handle cell arrays too
            if iscell(property_dictionary)
                temp_property_dictionary = containers.Map();
                for i = 1:length(property_dictionary)
                    prop_data = property_dictionary{i};
                    name = prop_data{1};
                    temp_property_dictionary(name) = prop_data;
                end
                property_dictionary = temp_property_dictionary;
            end
            % This function will go through and check to make sure that
            % everything that needs to be defined is defined, and that all
            % dimensions are consistent.
            variable_dimensions = containers.Map();
            missing_properties = {};
            invalid_choices = {};
            bad_types = {};
            bad_sizes = {};
            invalid_enumerations = {};
            invalid_regexes = {};
            property_names = keys(property_dictionary);
            isvalid = true;
            for i = 1:length(property_names)
                name = property_names{i};
                property_info = property_dictionary(name);
                if isa(property_info,'containers.Map')
                    valid_choice = obj.find_valid_choice_specification(property_info);
                    if length(valid_choice) < 1
                        invalid_choices{end+1} = name;
                        continue;
                    end
                    if length(valid_choice) > 1
                        error('Determining bewteen multiple valid choices is not implemented yet!')
                    end
                    % Since we already satisfied, name, type, and size, we
                    % should just only have to check that the names are
                    % consistent.
                    all_property_info = property_info(valid_choice{1});
                    for k = 1:length(all_property_info)
                        property_info = all_property_info{k};
                        % Go through everything and make sure it makes sense
                        property_name = property_info{1};
                        property_size = property_info{3};
                        property = obj.(property_name);
                        current_property_size = property.get_size();
                        for j = 1:length(property_size)
                            this_size = property_size{j};
                            this_current_size = current_property_size(j);
                            if ischar(this_size)
                                if ~isKey(variable_dimensions,this_size)
                                    variable_dimensions(this_size) = {};
                                end
                                this_dimension_info = variable_dimensions(this_size);
                                this_dimension_info{end+1} = {property_name,this_current_size};
                                variable_dimensions(this_size) = this_dimension_info;
                            else
                                if this_size ~= this_current_size
                                    bad_sizes{end+1} = {property_name,this_current_size,this_size,j};
                                end
                            end
                        end
                    end
                else
                    % Go through everything and make sure it makes sense
                    property_name = property_info{1};
                    property_type = property_info{2};
                    property_size = property_info{3};
                    property_options = property_info{4};
                    % Extract the object
                    property = obj.(property_name);
                    if isempty(property) && ~any(strcmpi(property_options,'optional'))
                        missing_properties{end+1} = property_name;
                        continue
                    elseif isempty(property) && any(strcmpi(property_options,'optional'))
                        continue
                    end
                    % Check the type and size
                    if ~strcmpi(property.get_format(),property_type)
                        bad_types{end+1} = {property_name,property.get_format(),property_type};
                        continue
                    end
                    current_property_size = property.get_size();
                    if length(current_property_size) ~= length(property_size)
                        bad_sizes{end+1} = {property_name, -1, -1, -1};
                        continue
                    end
                    for j = 1:length(property_size)
                        this_size = property_size{j};
                        if length(current_property_size) < j
                            bad_sizes{end+1} = {property_name, -1, this_size,j};
                            break
                        end
                        this_current_size = current_property_size(j);
                        if ischar(this_size)
                            if ~isKey(variable_dimensions,this_size)
                                variable_dimensions(this_size) = {};
                            end
                            this_dimension_info = variable_dimensions(this_size);
                            this_dimension_info{end+1} = {property_name,this_current_size};
                            variable_dimensions(this_size) = this_dimension_info;
                        else
                            if this_size ~= this_current_size
                                bad_sizes{end+1} = {property_name,this_current_size,this_size,j};
                            end
                        end
                    end
                    % Check if the enumerations or regexes are satisfied (if
                    % necessary)
                    for j = 1:length(property_options)
                        if strcmp(property_options{j}(1:5),'enum:')
                            split_enum = strtrim(strsplit(property_options{j},':'));
                            enum_name = split_enum{2};
                            valid_values = property_data{6}(enum_name);
                            enum_data = property(:);
                            valid_enums = ismember(enum_data,valid_values);
                            if ~all(valid_enums(:))
                                invalid_enumerations{end+1} = {property_name,valid_values,unique(enum_data(~valid_enums))};
                            end
                        end
                        if strcmp(property_options{j}(1:6),'regex:')
                            split_regex = strtrim(strsplit(property_options{j},':'));
                            pattern = split_regex{2};
                            regex_data = property(:);
                            matches = cellfun(@(x) ~isempty(regexp(x, pattern, 'once')), regex_data);
                            if ~all(matches(:))
                                invalid_regexes{end+1} = {property_name, unique(regex_data(~matches))};
                            end
                        end
                    end
                end
            end
            % Now make sure if everything is OK
            if ~isempty(missing_properties)
                isvalid = false;
                for i = 1:length(missing_properties)
                    missing_property = missing_properties{i};
                    if ~hide_issues
                        disp(['Required Property ',missing_property,' is missing.'])
                    end
                end
            end
            if ~isempty(invalid_choices)
                isvalid = false;
                for i = 1:length(invalid_choices)
                    invalid_choice = invalid_choices{i};
                    if ~hide_issues
                        disp(['No valid choice for ',invalid_choice,'.'])
                    end
                end
            end
            if ~isempty(bad_types)
                isvalid = false;
                for i = 1:length(bad_types)
                    bad_type = bad_types{i};
                    prop_name = bad_type{1};
                    prop_format = bad_type{2};
                    desired_format = bad_type{3};
                    if ~hide_issues
                        disp(['Property ',prop_name,' has type ',prop_format,' when it should be ',desired_format])
                    end
                end
            end
            if ~isempty(bad_sizes)
                isvalid = false;
                for i = 1:length(bad_sizes)
                    bad_size = bad_sizes{i};
                    prop_name = bad_size{1};
                    prop_size = bad_size{2};
                    desired_size = bad_size{3};
                    size_index = bad_size{4};
                    if prop_size == -1 && desired_size == -1 && size_index == -1
                        if ~hide_issues
                            disp(['Property ',prop_name,' dimensionality does not match'])
                        end
                    elseif prop_size == -1
                        if ~hide_issues
                            disp(['Property ',prop_name,' dimension ',num2str(size_index),' does not exist'])
                        end
                    else
                        if ~hide_issues
                            disp(['Property ',prop_name,' dimension ',num2str(size_index),' has size ',prop_size,' when it should be ',desired_size])
                        end
                    end
                end
            end
            if ~isempty(invalid_enumerations)
                isvalid = false;
                for i = 1:length(invalid_enumerations)
                    invalid_enumeration = invalid_enumerations{i};
                    prop_name = invalid_enumeration{1};
                    valid_values = invalid_enumeration{2};
                    bad_values = invalid_enumeration{3};
                    if ~hide_issues
                        disp(['Property ',prop_name,' has invalid values ',strjoin(bad_values,', '),'.  Values must be one of ',strjoin(valid_values,', ')])
                    end
                end
            end
            if ~isempty(invalid_regexes)
                isvalid = false;
                for i = 1:length(invalid_regexes)
                    invalid_regex = invalid_regexes{i};
                    prop_name = invalid_regex{1};
                    bad_values = invalid_regex{2};
                    if ~hide_issues
                        disp(['Property ',prop_name,' has invalid values ',strjoin(bad_values,', '),'.']);
                    end
                end
            end
            % Now go through the variable sized properties and make sure
            % they all match
            variable_dimension_keys = keys(variable_dimensions);
            for i = 1:length(variable_dimension_keys)
                variable_dimension = variable_dimension_keys{i};
                variable_dimension_data = variable_dimensions(variable_dimension);
                lengths = zeros(length(variable_dimension_data),1);
                for j = 1:length(variable_dimension_data)
                    lengths(j) = variable_dimension_data{j}{2};
                end
                if ~all(lengths == lengths(1))
                    isvalid = false;
                    if ~hide_issues
                        disp(['Dimension ',variable_dimension,' is inconsistent across properties.'])
                        for j = 1:length(variable_dimension_data)
                            disp(['  ',variable_dimension_data{j}{1},': ',num2str(variable_dimension_data{j}{2})])
                        end
                    end
                end
            end
            if obj.has_modified_properties && nargin == 1
                if ~hide_issues
                    disp('Dataset has modified properties and therefore cannot be valid.')
                end
                isvalid = false;
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
        end

        function help(obj)
        % Display specification documentation for this dataset type.
            [specification_info,~] = escdf_dataset.get_specification_info(obj.dataset_type);
            disp(specification_info{2})
            disp(specification_info{3})
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
        %     Ordered list of this dataset type and its parent types up the
        %     specification inheritance chain.
            [specification_data, ~] = escdf_dataset.get_specification_info(obj.get_type());
            supertype_list = {specification_data{1}};
            parent = specification_data{4};
            while ~strcmpi(parent,'none')
                [specification_data, ~] = escdf_dataset.get_specification_info(parent);
                supertype_list{end+1} = specification_data{1};
                parent = specification_data{4};
            end
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
        function dimension_names = get_dimension_names(obj)
            dimension_names = {};
            [~, property_dictionary] = escdf_dataset.get_specification_info(obj.get_type());
            property_keys = keys(property_dictionary);
            for i = 1:length(property_keys)
                key = property_keys{i};
                property_info = property_dictionary(key);
                if isa(property_info,'containers.Map')
                    option_keys = keys(property_info);
                    for j = 1:length(option_keys)
                        key = option_keys{j};
                        option_properties = property_info(key);
                        for k = 1:length(option_properties)
                            property_data = option_properties{k};
                            property_size = property_data{3};
                            for l = 1:length(property_size)
                                if ~isnumeric(property_size{l}) && ~any(strcmp(dimension_names,property_size{l}))
                                    dimension_names{end+1} = property_size{l};
                                end
                            end
                        end
                    end
                else
                    property_data = property_info;
                    property_size = property_data{3};
                    for l = 1:length(property_size)
                        if ~isnumeric(property_size{l}) && ~any(strcmp(dimension_names,property_size{l}))
                            dimension_names{end+1} = property_size{l};
                        end
                    end
                end
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
            % First we need to find all of the entries with that dimension
            % name
            [~, property_dictionary] = escdf_dataset.get_specification_info(obj.get_type());
            property_dimension_info = {};
            property_keys = keys(property_dictionary);
            for i = 1:length(property_keys)
                key = property_keys{i};
                property_info = property_dictionary(key);
                if isa(property_info,'containers.Map')
                    option_keys = keys(property_info);
                    for j = 1:length(option_keys)
                        key = option_keys{j};
                        option_properties = property_info(key);
                        for k = 1:length(option_properties)
                            property_data = option_properties{k};
                            property_size = property_data{3};
                            % Find matching dimension name
                            dimension_matches = strcmp(property_size,dimension_name);
                            if any(dimension_matches)
                                property_dimension_info{end+1} = {property_data{1},property_data{2},property_data{3},property_data{4},dimension_matches};
                            end
                        end
                    end
                else
                    property_data = property_info;
                    property_size = property_data{3};
                    % Find matching dimension name
                    dimension_matches = strcmp(property_size,dimension_name);
                    if any(dimension_matches)
                        property_dimension_info{end+1} = {property_data{1},property_data{2},property_data{3},property_data{4},dimension_matches};
                    end
                end
            end
            % Now we need to parse through and create the table
            column_names = {};
            data_array = {};
            for i = 1:length(property_dimension_info)
                name = property_dimension_info{i}{1};
                type = property_dimension_info{i}{2};
                dimension_names = property_dimension_info{i}{3};
                options = property_dimension_info{i}{4};
                dimension_match = find(property_dimension_info{i}{5},1);
                dimension_not_match = 1:length(dimension_names);
                dimension_not_match(dimension_match) = [];
                property = obj.(name);
                if isempty(property)
                    continue
                end
                if ~obj.validate({{name,type,dimension_names,options}},true)
                    continue
                end
                data = escdf_dataset.moveaxis(property(:),dimension_match,1);
                % Now we need to iterate over all dimension but the first
                indices = cell(1,length(dimension_names));
                sz = size(data);
                for j = 1:prod(sz(2:end))
                    size_array = sz(2:end);
                    dim = length(size_array);
                    if dim < 2
                        size_array = [size_array,1];
                    end
                    [indices{2:end}] = ind2sub(size_array,j);
                    indices{1} = ':';
                    slice = data(indices{:});
                    index_string = cell(1,length(dimension_names));
                    index_string{dimension_match} = ':';
                    index_string(dimension_not_match) = indices(2:end);
                    column_name = [name,'(',strjoin(cellfun(@num2str, index_string,'UniformOutput',false),','),')'];
                    data_array{end+1} = slice;
                    column_names{end+1} = column_name;
                    if j >= max_columns
                        break
                    end
                end
            end
            % Go through and make sure everything is the correct shape
            lengths = cellfun(@length,data_array);
            most_common_length = mode(lengths);
            inds_to_keep = lengths==most_common_length;
            column_names = column_names(inds_to_keep);
            data_array = data_array(inds_to_keep);
            table_out = table(data_array{:},'VariableNames',column_names);
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
        function [specification_data, property_dictionary] = get_specification_info(specification_name, force_reload)
        % Return parsed specification information for a dataset type.
        %
        % Parameters
        % ----------
        % specification_name : char
        %     Specification name to retrieve.
        % force_reload : logical, optional
        %     If true, force the specification cache to be rebuilt from the
        %     specification files.
        %
        % Returns
        % -------
        % specification_data : cell
        %     Parsed specification metadata.
        % property_dictionary : containers.Map
        %     Property-definition mapping for the requested
        %     specification.
            if nargin < 2
                force_reload = false;
            end
            persistent all_specification_data
            persistent all_property_dictionaries
            if isempty(all_specification_data) || force_reload
                if escdf_dataset.VERBOSE
                    disp('Parsing ESCDF Specification Files')
                end
                mfile_path = mfilename('fullpath');
                [path,~,~] = fileparts(mfile_path);
                specification_folder = fullfile(path,'specifications','*.txt');
                specification_files = dir(specification_folder);
                specification_files = {specification_files.name};
                all_specification_data = containers.Map();
                all_property_dictionaries = containers.Map();
                local_property_dictionaries = containers.Map();
                local_specification_data = containers.Map();
                for i = 1:length(specification_files)
                    file = specification_files{i};
                    file_path = fullfile(path,'specifications',strip(file));
                    [name, documentation, extra_documentation, parent_class, properties, enumerations, version] = escdf_dataset.parse_specification_file(file_path,escdf_dataset.VERBOSE);
                    local_specification_data(name) = {name, documentation, extra_documentation, parent_class, properties, enumerations, version};
                    local_property_dictionaries(name) = escdf_dataset.create_property_dictionary(properties);
                end
                % Now we want to go back through and get all of the
                % properties of all of the parent classes
                keysArray = keys(local_property_dictionaries);
                for i = 1:length(keysArray)
                    name = keysArray{i};
                    local_properties = {local_property_dictionaries(name)};
                    original_local_data = local_specification_data(name);
                    parent = original_local_data{4};
                    local_enumerations = {original_local_data{6}};
                    while ~strcmpi(parent,'none')
                        key = parent;
                        local_properties{end+1} = local_property_dictionaries(key);
                        local_data = local_specification_data(key);
                        parent = local_data{4};
                        local_enumerations{end+1} = local_data{6};
                    end
                    % Flip the order
                    local_properties = local_properties(end:-1:1);
                    local_enumerations = local_enumerations(end:-1:1);
                    local_property_dictionary = containers.Map();
                    local_enumeration_dictionary = containers.Map();
                    for j = 1:length(local_properties)
                        prop_dict = local_properties{j};
                        enum_dict = local_enumerations{j};
                        properties = keys(prop_dict);
                        for k = 1:length(properties)
                            key = properties{k};
                            if escdf_dataset.VERBOSE
                                disp(['Adding Property ',key,' to Dataset ',name])
                            end
                            val = prop_dict(key);
                            local_property_dictionary(key) = val;
                        end
                        enums = keys(enum_dict);
                        for k = 1:length(enums)
                            key = enums{k};
                            if escdf_dataset.VERBOSE
                                disp(['Adding Enumeration ',key,' to Dataset ',name])
                            end
                            val = enum_dict(key);
                            local_enumeration_dictionary(key) = val;
                        end
                    end
                    all_property_dictionaries(name) = local_property_dictionary;
                    all_specification_data(name) = [original_local_data(1:5),{local_enumeration_dictionary},original_local_data(7:end)];
                end
            end
            specification_data = all_specification_data(specification_name);
            property_dictionary = all_property_dictionaries(specification_name);
        end

        function reload_specification_cache()
        % Force re-parse of specification files.
        %
        % Notes
        % -----
        % This rebuilds the persistent specification cache so that newly
        % created or modified specification files are visible immediately.
            escdf_dataset.get_specification_info('parameter_set', true);
        end

        function [name, documentation, extra_documentation, parent_class, properties, enumerations, version] = parse_specification_file(specification_file, verbose)
            acceptable_datatypes = {'i1','i2','i4','i8','f4','f8','c8','c16', 'u1','u2','u4','u8','str','bytes'};
            if nargin < 2
                verbose = false;
            end
            %% Load in the file
            if verbose
                fprintf('Parsing %s\n', specification_file);
            end
            fid = fopen(specification_file, 'r');
            lines = textscan(fid, '%s', 'Delimiter', '\n');
            lines = lines{1};
            fclose(fid);
            %% Parse the Name
            line_parts = strsplit(lines{1},'-');
            name_part = line_parts{1};
            version_part = line_parts{2};
            name = strrep(strtrim(name_part), ' ', '_');
            version_parts = strsplit(strrep(version_part,'v',''),'.');
            major = str2double(version_parts{1});
            minor = str2double(version_parts{2});
            hotfix = str2double(version_parts{3});
            version = [major,minor,hotfix];
            if verbose
                fprintf('  Name %s\n', name);
                fprintf('  Version %d.%d.%d\n', major,minor,hotfix);
            end
            %% Find the extends line
            extends_line = find(cellfun(@(x) length(x) >= 8 && strcmp(x(1:8), 'extends:'), lines), 1);
            parent_class = strtrim(strsplit(lines{extends_line}, ':'));
            parent_class = parent_class{2};
            if verbose
                fprintf('  Found Parent Class %s at line %d\n', parent_class, extends_line);
            end
            %% Find the properties section
            properties_line = find(cellfun(@(x) strcmp(strtrim(x), 'properties'), lines), 1);
            if verbose
                fprintf('  Found Properties Header at Line %d\n', properties_line);
            end
            properties = {};
            for i = properties_line+2:length(lines)
                line = strtrim(lines{i});
                if isempty(line)
                    break;
                end
                if verbose
                    fprintf('  Found Property at Line %d\n', i);
                end
                property_info = strtrim(strsplit(line, '-'));
                % If there are any -'s in the options, it will have gotten
                % split apart, so let's recompile the options.
                property_info(4) = {strjoin(property_info(4:end),'-')};
                property_info = property_info(1:4);
                property_name = property_info{1};
                if verbose
                    fprintf('    Name: %s\n', property_name);
                end
                property_type = property_info{2};
                if ~ismember(property_type, acceptable_datatypes)
                    error('In file %s variable %s, %s is not a valid type. Must be one of %s', specification_file, property_name, property_type, strjoin(acceptable_datatypes, ', '));
                end
                if verbose
                    fprintf('    Type: %s\n', property_type);
                end
                try
                    if strcmp(property_info{3}, 'scalar')
                        property_shape = {};
                    else
                        property_shape = strsplit(property_info{3}, ',');
                    end
                catch
                    property_shape = {};
                end
                if verbose
                    fprintf('    Shape: %s\n', string(property_shape));
                end
                for j = 1:length(property_shape)
                    try
                        shape = str2double(property_shape{j});
                        if isnan(shape)
                            property_shape{j} = strtrim(property_shape{j});
                        else
                            property_shape{j} = shape;
                        end
                    catch
                        property_shape{j} = strtrim(property_shape{j});
                    end
                end
                try
                    if isempty(property_info{4})
                        property_options = {};
                    else
                        property_options = strtrim(strsplit(property_info{4}, ','));
                        % If there is "regex" in any of them, we need to join
                        % with the rest, because it could have a , in it which
                        % would split up one property into multiple
                        regex_found = find(contains(property_options,'regex:'),1);
                        if ~isempty(regex_found)
                            property_options(regex_found) = {strjoin(property_options(regex_found:end),',')};
                            property_options = property_options(1:regex_found);
                        end
                    end
                catch
                    property_options = {};
                end
                if verbose
                    fprintf('    Options: %s\n', strjoin(property_options, ', '));
                end
                properties{end+1} = {property_name, property_type, property_shape, property_options};
            end
            %% Find the Enumerations section if it exists
            enumerations_line = find(cellfun(@(x) strcmp(strtrim(x), 'enumerations'), lines), 1);
            enumerations = containers.Map();
            if isempty(enumerations_line)
                if verbose
                    fprintf('  No Enumerations Found\n');
                end
            else
                if verbose
                    fprintf('  Found Enumeration Header at Line %d\n', enumerations_line);
                end
                for i = enumerations_line+2:length(lines)
                    line = strtrim(lines{i});
                    if isempty(line)
                        break;
                    end
                    if verbose
                        fprintf('  Found Enumeration at Line %d\n', i);
                    end
                    enumeration_info = strtrim(strsplit(line, '-'));
                    enumeration_name = enumeration_info{1};
                    if verbose
                        fprintf('    Name: %s\n', enumeration_name);
                    end
                    enumeration_values = strtrim(strsplit(strjoin(enumeration_info(2:end),'-'), ','));
                    if verbose
                        fprintf('    Values: %s\n', strjoin(enumeration_values,', '));
                    end
                    enumerations(enumeration_name) = enumeration_values;
                end
            end

            %% Grab the documentation
            documentation = strjoin(lines(extends_line+1:properties_line-1), '\n');
            if verbose
                fprintf('  Documentation\n');
                fprintf('%s\n', documentation);
            end
            extra_documentation = strjoin(lines(i+1:end), '\n');
            if verbose
                fprintf('  Extra Documentation\n');
                fprintf('%s\n', extra_documentation);
            end
        end

        function output_dict = create_property_dictionary(properties)
            output_dict = containers.Map();
            for i = 1:length(properties)
                property_name = properties{i}{1};
                property_type = properties{i}{2};
                property_shape = properties{i}{3};
                property_options = properties{i}{4};
                is_option = false;
                % Parse the options:
                if ~isempty(property_options)
                    % Loop through and see if it's an "or"
                    for j = 1:length(property_options)
                        option = property_options{j};
                        if startsWith(option, 'or:')
                            parts = strsplit(option, ':');
                            option_name = parts{2};
                            option_choice = parts{3};
                            if ~isKey(output_dict, option_name)
                                output_dict(option_name) = containers.Map();
                            end
                            if ~isKey(output_dict(option_name), option_choice)
                                key = output_dict(option_name);
                                key(option_choice) = {};
                                output_dict(option_name) = key;
                            end
                            output_properties = property_options(~startsWith(property_options, 'or:'));
                            if isempty(output_properties)
                                output_properties = {};
                            end
                            key = output_dict(option_name);
                            current_list = key(option_choice);
                            current_list{end+1} = {property_name, property_type, property_shape, output_properties};
                            key(option_choice) = current_list;
                            output_dict(option_name) = key;
                            is_option = true;
                            break;
                        end
                    end
                    if is_option
                        continue;
                    end
                end
                output_dict(property_name) = {property_name, property_type, property_shape, property_options};
            end
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

        function isacceptable = check_if_property_is_acceptable(acceptable_specifications, property)
            isacceptable = false;
            for i = 1:length(acceptable_specifications)
                acceptable_specification = acceptable_specifications{i};
                name = acceptable_specification{1};
                format = acceptable_specification{2};
                size = acceptable_specification{3};
                ragged = ismember('variable_length',acceptable_specification{4});
                % Check that the names are the same
                if ~strcmp(name,property.get_name())
                    % If they aren't, we can directly go to the next
                    % specification.
                    continue
                end
                % Check if the formats are the same
                if ~strcmp(format,property.get_format())
                    % If they don't match, go to the next specification
                    continue
                end
                % Check if they are both ragged
                if ragged ~= property.isragged()
                    continue
                end
                % Check if the sizes are the same (or at least consistent)
                actual_size = property.get_size();
                if length(size) ~= length(actual_size)
                    continue
                end

                all_sizes_match = true;
                for j = 1:length(size)
                    acceptable_size = size{j};
                    if ischar(acceptable_size)
                        % Here we won't check if the size is variable.
                        continue
                    else
                        if acceptable_size ~= actual_size(j)
                            all_sizes_match = false;
                            break
                        end
                    end
                end
                if ~all_sizes_match
                    continue
                end
                % If we get to this point, then we match all of the
                % parameters so we are good to go.
                isacceptable = true;
                break
            end
        end

        function property = build_property_from_array(name,acceptable_specifications,array)
            % Here we will go through and basically build a property
            % for each one and see which fits the best.
            preferred_type_order = {'u1','u2','u4','u8','i1','i2','i4','i8',...
                'f4','f8','c8','c16','str','bytes'};
            % We will collect properties and score them based on our
            % preferences.
            all_properties = {};
            % We will prefer smaller numbers of dimensions
            dimension_scores = [];
            % We will prefer smaller datatypes
            type_scores = [];
            for j = 1:length(acceptable_specifications)
                property_data = acceptable_specifications{j};
                sizes = [];
                if isempty(property_data{3})
                    size_name = 'scalar';
                else
                    size_name = strjoin(cellfun(@num2str,property_data{3},'UniformOutput',false),',');
                    for i = 1:length(property_data{3})
                        if isnumeric(property_data{3}{i})
                            sizes(end+1) = property_data{3}{i};
                        else
                            data_size = size(array);
                            if i > length(data_size)
                                sizes(end+1) = 1;
                            else
                                sizes(end+1) = data_size(i);
                            end
                        end
                    end
                end
                if escdf_dataset.VERBOSE
                    disp(['Name: ',name])
                    disp(['Type: ',property_data{2}])
                    disp(['Size: ',size_name,' (',num2str(sizes),')'])
                    disp(['Options: ',strjoin(property_data{4})])
                end
                property = escdf_property(name,property_data{2},sizes,'ragged',ismember('variable_length',property_data{4}));
                try
                    property(:) = array;
                catch
                    continue
                end
                % Now we need to check if the data has been preserved.  If
                % it hasn't, then that is not a good datatype.
                if isequal(property.get_data(),array) || (length(acceptable_specifications) == 1)
                    all_properties{end+1} = property;
                    dimension_scores(end+1) = length(property.get_size());
                    type_scores(end+1) = find(strcmp(preferred_type_order,property.get_format()));
                end
            end
            if length(all_properties) < 1
                error(['Could not build a escdf_property ',name,' to match the requested specifications.'])
            end
            [~,min_index] = min(dimension_scores+type_scores*10);
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
            % First let's find all of the options that it could be.
            [specification_data, property_dictionary] = escdf_dataset.get_specification_info(obj.dataset_type);
            % First let's see if it's just a regular old key
            property_data = {};
            try
                this_property_data = property_dictionary(name);
                if ~isa(this_property_data,'containers.Map')
                    property_data{end+1} = this_property_data;
                end
            end
            % If we didn't find it, we'll have to look through all of the
            % options.
            if isempty(property_data)
                property_keys = keys(property_dictionary);
                for i = 1:length(property_keys)
                    property_key = property_keys{i};
                    this_property_data = property_dictionary(property_key);
                    if isa(this_property_data,'containers.Map')
                        % Look through all of the properties
                        option_keys = keys(this_property_data);
                        for j = 1:length(option_keys)
                            option_key = option_keys{j};
                            option_properties = this_property_data(option_key);
                            for k = 1:length(option_properties)
                                this_property = option_properties{k};
                                if strcmpi(this_property{1},name)
                                    property_data{end+1} = this_property;
                                end
                            end
                        end
                    end
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
                    this_property = escdf_dataset.build_property_from_array(name,property_data,val);
                end
            end
            if ~escdf_dataset.check_if_property_is_acceptable(property_data,this_property)
                error(['Assigned property is not consistent with the specification for ',name])
            end
            obj.(['DO_NOT_USE_',name]) = this_property;
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
            try
                [sd, pd] = escdf_dataset.get_specification_info(data_type);
            catch
                warning(sprintf('Dataset %s has an undefined type %s and will be written to an unknown dataset.',name,data_type))
                original_data_type = data_type;
                data_type = 'unknown';
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
end
