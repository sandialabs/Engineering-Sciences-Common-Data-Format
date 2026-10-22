classdef escdf_activity < handle
% ESCDF_ACTIVITY Activity container for ESCDF result datasets.
%
% An escdf_activity represents one test, analysis step, or processing
% action within an ESCDF file. Activities hold datasets that inherit from
% activity_result and may also reference one or more metadata datasets by
% name.
%
% Parameters
% ----------
% short_name : char
%     Short activity identifier used as the on-disk activity group name.
% descriptive_name : char
%     Human-readable activity description.
% activity_date : datetime
%     Date and time associated with the activity.
% data : escdf_dataset array, optional
%     Initial result datasets contained in the activity.
% metadata_links : cell array of char, optional
%     Names of metadata datasets linked to the activity.
% replace_invalid_names : logical, optional
%     If true, invalid activity names are repaired automatically.
%
% Notes
% -----
% Activities do not store metadata datasets directly. Instead, they
% maintain references to metadata dataset names stored elsewhere in the
% parent escdf container.
%
% See Also
% --------
% escdf
% escdf_dataset

    properties (Access=private)
        data;
        metadata_links;
        name;
        descriptive_name;
        activity_date;
        backing_state;
        has_pending_changes;
        logical_parent;
        hdf5_location;
    end

    methods
        function obj = escdf_activity(short_name,descriptive_name,activity_date,data,metadata_links,replace_invalid_names)
        % Create an ESCDF activity.
        %
        % Parameters
        % ----------
        % short_name : char
        %     Short activity identifier used as the on-disk activity group
        %     name.
        % descriptive_name : char
        %     Human-readable activity description.
        % activity_date : datetime
        %     Date and time associated with the activity.
        % data : escdf_dataset array, optional
        %     Initial result datasets contained in the activity.
        % metadata_links : cell array of char, optional
        %     Names of metadata datasets linked to the activity.
        % replace_invalid_names : logical, optional
        %     If true, invalid activity names are repaired automatically.
        %
        % Raises
        % ------
        % error
        %     Raised if the activity name is invalid and
        %     replace_invalid_names is false, or if the supplied data or
        %     metadata links are malformed.
            if nargin < 4 || isempty(data)
                obj.data = escdf_dataset.empty(1,0);
            elseif isa(data,'escdf_dataset')
                obj.data = data(:).';
            else
                error('Data must be supplied as an array of escdf_datasets or an empty array []')
            end
            if nargin < 5 || isempty(metadata_links)
                obj.metadata_links = {};
            elseif iscellstr(metadata_links)
                obj.metadata_links = metadata_links(:).';
            else
                error('Metadata references must be stored as a cell array of strings')
            end
            if nargin < 6
                replace_invalid_names = false;
            end
            % Check if name is valid
            name_valid = escdf.is_valid_identifier(short_name);
            if (~name_valid) && replace_invalid_names
                short_name = escdf.make_valid_identifier(short_name, 'activity_');
            elseif (~name_valid) && ~replace_invalid_names
                error('Invalid Name %s.  Names must start with a letter and consist of only letters, numbers, and underscores.',short_name)
            end
            obj.name = short_name;
            obj.descriptive_name = descriptive_name;
            obj.logical_parent = [];
            if isa(activity_date,'datetime')
                obj.activity_date = activity_date;
            else
                error('activity_date must be a datetime object')
            end

            obj.backing_state = 'memory';
            obj.hdf5_location = [];
            obj.has_pending_changes = false;
        end

        function link_to_metadata(obj,metadata_name)
        % Add a metadata link to the activity.
        %
        % Parameters
        % ----------
        % metadata_name : char
        %     Name of the metadata dataset to link.
        %
        % Raises
        % ------
        % error
        %     Raised if the metadata name is already linked to this
        %     activity.
            if any(strcmp(obj.metadata_links,metadata_name))
                error(['Activity ',obj.name,' is already linked to metadata ',metadata_name])
            end
            obj.metadata_links{end+1} = metadata_name;
            obj.has_pending_changes = true;
        end

        function unlink_from_metadata(obj,metadata_name)
        % Remove a metadata link from the activity.
        %
        % Parameters
        % ----------
        % metadata_name : char
        %     Name of the metadata dataset to unlink.
        %
        % Raises
        % ------
        % error
        %     Raised if the metadata name is not currently linked to the
        %     activity.
            index = find(strcmp(obj.metadata_links,metadata_name));
            if length(index) > 1
                error(['Multiple metadata links with the same name (',metadata_name,') in activity ',obj.name])
            elseif isempty(index)
                error(['Metadata ',metadata_name,' does not exist in activity ',obj.name])
            else
                obj.metadata_links = remove_array_index(obj.metadata_links, index);
                obj.has_pending_changes = true;
            end
        end

        function name = get_name(obj)
        % Return the activity short name.
        %
        % Returns
        % -------
        % name : char
        %     Activity identifier used as the on-disk activity group name.
            name = obj.name;
        end

        function set_name(obj, new_name)
        % Set the activity logical name.
        %
        % Parameters
        % ----------
        % new_name : char
        %     New activity name.
            if ~(ischar(new_name) || isstring(new_name))
                error('New activity name must be a string.');
            end
            new_name = char(string(new_name));

            if ~escdf.is_valid_identifier(new_name)
                error('New activity name "%s" is not a valid identifier.', new_name);
            end

            obj.name = new_name;
            obj.has_pending_changes = true;
        end

        function name = get_descriptive_name(obj)
        % Return the activity descriptive name.
        %
        % Returns
        % -------
        % name : char
        %     Human-readable activity description.
            name = obj.descriptive_name;
        end

        function date = get_date(obj)
        % Return the activity date.
        %
        % Returns
        % -------
        % date : datetime
        %     Date and time associated with the activity.
            date = obj.activity_date;
        end

        function out = get_backing_state(obj)
        % Return the activity backing state.
        %
        % Returns
        % -------
        % out : char
        %     Activity backing state.
            out = obj.backing_state;
        end

        function out = get_has_pending_changes(obj)
        % Return whether the activity has pending changes.
        %
        % Returns
        % -------
        % out : logical
        %     True if the activity has pending changes relative to its
        %     current authoritative/reference state.
            out = obj.has_pending_changes;
        end

        function set_backing_state(obj, state)
        % Set the activity backing state.
            obj.backing_state = state;
        end

        function set_has_pending_changes(obj, tf)
        % Set the activity pending-changes flag.
            obj.has_pending_changes = tf;
        end

        function parent = get_logical_parent(obj)
        % Return the logical parent container for this activity.
        %
        % Returns
        % -------
        % parent : escdf or []
        %     Parent ESCDF container if attached, otherwise empty.
            parent = obj.logical_parent;
        end

        function set_logical_parent(obj, parent)
        % Set the logical parent for this activity.
        %
        % Parameters
        % ----------
        % parent : escdf or []
        %     Parent container, or empty for a free activity.
            obj.logical_parent = parent;
        end

        function ancestry = get_logical_ancestry(obj)
        % Return the logical ancestry chain beginning with this activity.
        %
        % Returns
        % -------
        % ancestry : cell array
        %     Bottom-up logical ancestry beginning with this activity.
            ancestry = {obj};
            parent = obj.get_logical_parent();
            while ~isempty(parent)
                ancestry{end+1} = parent; %#ok<AGROW>
                if ismethod(parent, 'get_logical_parent')
                    parent = parent.get_logical_parent();
                else
                    parent = [];
                end
            end
        end

        function root = get_logical_root(obj)
        % Return the root object of this activity's logical graph.
        %
        % Returns
        % -------
        % root : object
        %     Last object in the bottom-up logical ancestry chain.
            ancestry = obj.get_logical_ancestry();
            root = ancestry{end};
        end

        function path = get_logical_path(obj)
        % Return the root-relative logical path for this activity.
        %
        % Returns
        % -------
        % path : char or []
        %     Logical path if attached to a container, otherwise empty.
            parent = obj.get_logical_parent();
            if isempty(parent)
                path = [];
                return
            end

            path = ['/activities/', obj.get_name()];
        end

        function tf = same_logical_location_as(obj, other)
        % Return whether this object occupies the same logical location as
        % another object.
        %
        % Parameters
        % ----------
        % other : object
        %     Object to compare against.
        %
        % Returns
        % -------
        % tf : logical
        %     True if both objects have the same logical ancestry by handle
        %     identity.
            tf = false;

            if ~ismethod(other, 'get_logical_ancestry')
                return
            end

            this_ancestry = obj.get_logical_ancestry();
            other_ancestry = other.get_logical_ancestry();

            if length(this_ancestry) ~= length(other_ancestry)
                return
            end

            for i = 1:length(this_ancestry)
                if ~(this_ancestry{i} == other_ancestry{i})
                    return
                end
            end

            tf = true;
        end

        function location = get_hdf5_location(obj)
        % Return the current HDF5 backing location for this activity.
        %
        % Returns
        % -------
        % location : HDF5Location or []
        %     HDF5 group location if HDF5-backed, otherwise empty.
            location = obj.hdf5_location;
        end

        function set_hdf5_location(obj, location)
        % Set the current HDF5 backing location for this activity.
        %
        % Parameters
        % ----------
        % location : HDF5Location or []
        %     HDF5 group location, or empty for memory-backed.
            obj.hdf5_location = location;
        end

        function location = get_target_hdf5_location(obj, activities_group_id)
        % Return the HDF5 location this activity would occupy under an
        % activities group.
        %
        % Parameters
        % ----------
        % activities_group_id : numeric
        %     HDF5 activities group identifier.
        %
        % Returns
        % -------
        % location : HDF5Location
        %     Expected HDF5 group location for this activity.
            location = HDF5Location.child_of_group(activities_group_id, obj.get_name());
        end

        function tf = is_realized_at(obj, activity_group_id)
        % Return whether this activity is already realized at an HDF5 group.
        %
        % Parameters
        % ----------
        % activity_group_id : numeric
        %     HDF5 group identifier representing the target activity.
        %
        % Returns
        % -------
        % tf : logical
        %     True if this activity is HDF5-backed at exactly the given
        %     group location.
            current = obj.get_hdf5_location();
            if isempty(current)
                tf = false;
                return
            end

            target = HDF5Location.from_hdf5_id(activity_group_id);
            tf = current.same_location_as(target);
        end

        function tf = is_realized_under(obj, activities_group_id)
        % Return whether this activity is already realized under an
        % activities parent group.
        %
        % Parameters
        % ----------
        % activities_group_id : numeric
        %     HDF5 activities group identifier.
        %
        % Returns
        % -------
        % tf : logical
        %     True if this activity is HDF5-backed at the expected child
        %     location under the activities group.
            current = obj.get_hdf5_location();
            if isempty(current)
                tf = false;
                return
            end

            target = obj.get_target_hdf5_location(activities_group_id);
            tf = current.same_location_as(target);
        end

        function tf = same_backing_location_as(obj, other)
        % Return whether this activity has the same HDF5 backing location
        % as another activity.
        %
        % Parameters
        % ----------
        % other : object
        %     Object to compare against.
        %
        % Returns
        % -------
        % tf : logical
        %     True if both activities are HDF5-backed at the same HDF5
        %     group location.
            tf = false;

            if ~ismethod(other, 'get_hdf5_location')
                return
            end

            this_location = obj.get_hdf5_location();
            other_location = other.get_hdf5_location();

            if isempty(this_location) || isempty(other_location)
                return
            end

            tf = this_location.same_location_as(other_location);
        end

        function add_data(obj,dataset)
        % Add a result dataset to the activity.
        %
        % Parameters
        % ----------
        % dataset : escdf_dataset
        %     Dataset to add.
        %
        % Raises
        % ------
        % error
        %     Raised if the input is not an escdf_dataset, if the dataset
        %     does not inherit from activity_result (or unknown), or if a
        %     dataset with the same name already exists in the activity.
            if ~isa(dataset,'escdf_dataset')
                error('Data added to activities must be in the form of an escdf_dataset')
            end
            if ~(dataset.istype('activity_result')) && ~(dataset.istype('unknown'))
                error(['escdf_datasets added to activities should be an "activity_result" or inherit from it, not ',dataset.get_type(),'.  Add this as metadata then link the metadata to the activity.'])
            end
            if any(strcmp(obj.get_data_names(),dataset.get_name()))
                error(['Data with name ',dataset.get_name(),' already exists in this activity.'])
            end
            dataset.set_logical_parent(obj)
            obj.data = [obj.data,dataset];
            obj.has_pending_changes = true;
        end

        function removed = remove_data(obj, data_name)
        % Remove a dataset from this activity.
        %
        % Parameters
        % ----------
        % data_name : char
        %     Name of the dataset to remove.
        %
        % Returns
        % -------
        % removed : escdf_dataset
        %     The removed dataset object.
        %
        % Raises
        % ------
        % error
        %     Raised if no dataset with the given name exists in the
        %     activity.
        %
        % Notes
        % -----
        % This operation removes the dataset from the in-memory activity
        % graph only. It does not immediately delete any underlying
        % physical backing from disk.
            index = [];
            for i = 1:length(obj.data)
                if strcmp(obj.data(i).get_name(), data_name)
                    index = i;
                    break
                end
            end
            if isempty(index)
                error(['No dataset with name ',data_name,' was found in this activity.'])
            end

            removed = obj.data(index);
            obj.data = remove_array_index(obj.data, index);
            removed.set_logical_parent([]);
            obj.has_pending_changes = true;
        end

        function renamed = rename_data(obj, old_name, new_name)
        % Rename a dataset within this activity.
        %
        % Parameters
        % ----------
        % old_name : char
        %     Current dataset name.
        % new_name : char
        %     New dataset name.
        %
        % Returns
        % -------
        % renamed : escdf_dataset
        %     The renamed dataset object.
        %
        % Raises
        % ------
        % error
        %     Raised if the old name does not exist, the new name already
        %     exists, or the new name is not a valid identifier.
        %
        % Notes
        % -----
        % This operation updates only the in-memory logical graph. It does
        % not immediately rename any physical HDF5 backing.
            if ~(ischar(new_name) || isstring(new_name))
                error('New dataset name must be a string.');
            end
            new_name = char(string(new_name));

            if ~escdf.is_valid_identifier(new_name)
                error('New dataset name "%s" is not a valid identifier.', new_name);
            end

            old_index = [];
            for i = 1:length(obj.data)
                if strcmp(obj.data(i).get_name(), old_name)
                    old_index = i;
                    break
                end
            end
            if isempty(old_index)
                error('No dataset named "%s" exists in activity "%s".', old_name, obj.name);
            end

            for i = 1:length(obj.data)
                if strcmp(obj.data(i).get_name(), new_name)
                    error('A dataset named "%s" already exists in activity "%s".', new_name, obj.name);
                end
            end

            renamed = obj.data(old_index);
            renamed.set_name(new_name);
            obj.has_pending_changes = true;
        end

        function removed = replace_data(obj, dataset)
        % Replace a dataset within this activity.
        %
        % Parameters
        % ----------
        % dataset : escdf_dataset
        %     Dataset to use as the replacement. Its name must match an
        %     existing dataset in the activity.
        %
        % Returns
        % -------
        % removed : escdf_dataset
        %     The removed dataset object.
        %
        % Raises
        % ------
        % error
        %     Raised if the replacement dataset name does not already
        %     exist in the activity.
        %
        % Notes
        % -----
        % This operation updates only the in-memory logical graph. It does
        % not immediately modify any physical HDF5 backing.
            if ~isa(dataset, 'escdf_dataset')
                error('Replacement dataset must be an escdf_dataset object.');
            end

            if ~any(strcmp(obj.get_data_names(), dataset.get_name()))
                error('No dataset named "%s" exists in activity "%s" to replace.', ...
                    dataset.get_name(), obj.name);
            end

            removed = obj.remove_data(dataset.get_name());
            obj.add_data(dataset);
            obj.has_pending_changes = true;
        end

        function link_names = get_metadata_links(obj)
        % Return names of metadata datasets linked to the activity.
        %
        % Returns
        % -------
        % link_names : cell array of char
        %     Metadata dataset names linked to the activity.
            link_names = obj.metadata_links;
        end

        function data = get_data(obj,dataset_name)
        % Retrieve one or more datasets from the activity.
        %
        % Parameters
        % ----------
        % dataset_name : char, optional
        %     Name of a specific dataset to retrieve. If omitted, all
        %     datasets in the activity are returned.
        %
        % Returns
        % -------
        % data : escdf_dataset or escdf_dataset array
        %     Requested dataset, or the full activity dataset collection.
        %
        % Raises
        % ------
        % error
        %     Raised if a specific dataset name is requested but no
        %     matching dataset exists.
            if nargin < 2
                data = obj.get_all_data();
            else
                data = obj.get_data_from_name(dataset_name);
            end
        end

        function rename_metadata_link(obj, old_name, new_name)
        % Rename a metadata link within this activity.
        %
        % Parameters
        % ----------
        % old_name : char
        %     Existing metadata link name.
        % new_name : char
        %     Replacement metadata link name.
        %
        % Notes
        % -----
        % This updates only the in-memory logical activity state.
            match = find(strcmp(obj.metadata_links, old_name), 1);
            if isempty(match)
                error('Metadata link "%s" was not found in activity "%s".', old_name, obj.name);
            end
            obj.metadata_links{match} = new_name;
            obj.has_pending_changes = true;
        end

        function all_data = get_all_data(obj)
        % Return all datasets in the activity.
        %
        % Returns
        % -------
        % all_data : escdf_dataset array
        %     All datasets contained in the activity.
            all_data = obj.data;
        end
        
        function names = get_data_names(obj)
        % Return dataset names contained in the activity.
        %
        % Returns
        % -------
        % names : cell array of char
        %     Names of datasets contained in the activity.
            names = arrayfun(@(x) x.get_name(),obj.data,'UniformOutput',false);
        end

        function disp(obj)
            fprintf('%s\n\n',obj.repr())
        end

        function out = repr(obj)
        % Return a text representation of the activity.
        %
        % Returns
        % -------
        % out : char
        %     Human-readable summary of the activity, its datasets, and its
        %     metadata links.
            out = [];
            for i = 1:length(obj)
                activity = obj(i);
                activity_name = activity.get_name();
                activity_descriptive_name = activity.get_descriptive_name();
                date = sprintf('\n      Date: %s',datestr(activity.get_date(),'yyyy-mm-dd HH:MM:SS.FFF'));
                if i == 1
                    initial_newlines = '';
                else
                    initial_newlines = sprintf('\n\n');
                end
                out = [out,sprintf('%s    %s:\n      %s%s',initial_newlines,activity_name,activity_descriptive_name, date)];
                data_names = activity.get_data_names();
                links = activity.get_metadata_links();
                out = [out,sprintf(['\n      Data:\n        ',strjoin(data_names,', ')])];
                out = [out,sprintf(['\n      Metadata Links:\n        ',strjoin(links,', ')])];
            end
        end

        function realize_to_hdf5(obj, activities_group_id, strategy, overwrite)
        % Realize the activity into an HDF5 activities group.
        %
        % Parameters
        % ----------
        % activities_group_id : numeric
        %     HDF5 group identifier containing all activities.
        % strategy : char, optional
        %     Dataset/property realization strategy. The first-pass
        %     implementation supports only 'memory'.
        % overwrite : logical, optional
        %     If true, allow replacing an existing activity group with the
        %     same name.
            if nargin < 3
                strategy = 'memory';
            end
            if nargin < 4
                overwrite = false;
            end

            if H5L.exists(activities_group_id, obj.name, 'H5P_DEFAULT')
                if ~overwrite
                    error('Target activities group already contains activity "%s". Use overwrite=true to replace it explicitly.', obj.name)
                end
                H5L.delete(activities_group_id, obj.name, 'H5P_DEFAULT');
            end

            gid = H5G.create(activities_group_id,obj.name,'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');

            % Write activity attributes
            attr_space_id = H5S.create('H5S_SCALAR');
            str_type_id = H5T.copy('H5T_C_S1');
            H5T.set_size(str_type_id, 'H5T_VARIABLE');

            attr_id = H5A.create(gid, 'activity_name', str_type_id, attr_space_id, 'H5P_DEFAULT');
            H5A.write(attr_id, str_type_id, obj.descriptive_name);
            H5A.close(attr_id);

            attr_id = H5A.create(gid, 'activity_date', str_type_id, attr_space_id, 'H5P_DEFAULT');
            H5A.write(attr_id, str_type_id, char(escdf.datetime_to_iso_utc(obj.activity_date)));
            H5A.close(attr_id);

            H5T.close(str_type_id);
            H5S.close(attr_space_id);

            % Write metadata links
            str_type_id = H5T.copy('H5T_C_S1');
            H5T.set_size(str_type_id, 'H5T_VARIABLE');

            if isempty(obj.metadata_links)
                dataspace_id = H5S.create_simple(1, 0, 0);
            else
                dataspace_id = H5S.create_simple(1, length(obj.metadata_links), length(obj.metadata_links));
            end

            parameter_id = H5D.create(gid,'parameters',str_type_id,dataspace_id,'H5P_DEFAULT');
            H5D.write(parameter_id,str_type_id,'H5S_ALL','H5S_ALL','H5P_DEFAULT',obj.metadata_links);

            attr_space_id = H5S.create('H5S_SCALAR');
            attr_id = H5A.create(parameter_id, 'data_type', str_type_id, attr_space_id, 'H5P_DEFAULT');
            H5A.write(attr_id, str_type_id, 'str');
            H5A.close(attr_id);
            H5S.close(attr_space_id);

            H5D.close(parameter_id);
            H5S.close(dataspace_id);
            H5T.close(str_type_id);

            % Realize activity datasets
            for j = 1:length(obj.data)
                this_data = obj.data(j);
                this_gid = H5G.create(gid,this_data.get_name(),'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');
                this_data.realize_to_hdf5(this_gid, strategy, overwrite);
                H5G.close(this_gid);
            end

            obj.hdf5_location = HDF5Location.from_hdf5_id(gid);
            obj.backing_state = 'hdf5_native';
            obj.has_pending_changes = false;

            H5G.close(gid)
        end

        function write_to_disk(obj, activities_group_id)
        % Write the activity to an HDF5 activities group.
        %
        % Notes
        % -----
        % Compatibility wrapper around realize_to_hdf5.
            obj.realize_to_hdf5(activities_group_id,'memory',false);
        end

        function varargout = subsref(obj, S)
            switch S(1).type
                case '.'
                    % Check if the object is a name of a data object
                    requested_name = S(1).subs;
                    if numel(obj) == 1
                        % If the item has 1 item available to it, we could
                        % either be requesting an activity or a data.
                        % We will check the data first and then check the
                        % activity.
                        data_index = obj.get_data_index_from_name(requested_name);
                        if isempty(data_index) % If there is no data name that matches
                            % Then we check if there is an activity that
                            % matches.
                            activity_index = obj.get_activity_from_name(requested_name);
                            if isempty(activity_index) % If there is no activity name that matches
                                % Then we assume it's just a regular field
                                % name.
                                [varargout{1:nargout}] = builtin('subsref', obj, S);
                            else % If there is an activity that matches
                                if length(S) == 1 % If this is the last indexing operation
                                    % We simply return the object that we
                                    % are after
                                    varargout{1} = obj(activity_index);
                                else % If there are further indexing operations
                                    % We need to recursively pass that
                                    % activity to the subsref function with the
                                    % referenced activity as the input
                                    activity_reference = obj(activity_index);
                                    [varargout{1:nargout}] = subsref(activity_reference,S(2:end));
                                end
                            end
                        else % If there is data that matches the name
                            if length(S) == 1 % if this is the last indexing operation
                                % we simply return the data that we are
                                % after
                                varargout{1} = obj.get_data_from_name(requested_name);
                            else % If it is not the last indexing operation
                                % We need to recursively pass that data to
                                % the subsref function with the referenced
                                % data as the input.
                                data_reference = obj.get_data_from_name(requested_name);
                                [varargout{1:nargout}] = subsref(data_reference,S(2:end));
                            end
                        end
                    else % If there is more than one activity in our object
                        % then selecting for data does not make sense.  We
                        % need to first downselect to the correct activity
                        activity_index = obj.get_activity_from_name(requested_name);
                        if isempty(activity_index) % If there is no match
                            % Then what we are looking for is a regular
                            % property or method.
                            [varargout{1:nargout}] = builtin('subsref', obj, S);
                        else % If there is a match
                            if length(S) == 1 % If this is the last indexing operation
                                % Then we simply return the activity
                                varargout{1} = obj(activity_index);
                            else % Otherwise we need to pass the activity
                                % recursively to the subsref function.
                                activity_reference = obj(activity_index);
                                [varargout{1:nargout}] = subsref(activity_reference,S(2:end));
                            end
                        end
                    end
                otherwise
                    % Default handling for other types of indexing
                    [varargout{1:nargout}] = builtin('subsref', obj, S);
            end
        end

    end

    methods (Access = private)
        function index = get_data_index_from_name(obj,name)
            names = obj.get_data_names();
            index = find(strcmp(names,name));
        end

        function selected_data = get_data_from_name(obj,name)
            index = obj.get_data_index_from_name(name);
            if length(index) > 1
                error(['Multiple data with name ',name, '.  How did you get here?'])
            elseif isempty(index)
                error(['No data with name ',name])
            end
            selected_data = obj.data(index);
        end
        function index = get_activity_from_name(obj,name)
            all_names = {};
            for i = 1:numel(obj)
                this_obj = obj(i);
                all_names{end+1} = this_obj.get_name();
            end
            index = find(strcmp(all_names,name));
        end


    end

end

function modified_array = remove_array_index(array, index_to_remove)
% Check if the index is valid
if index_to_remove < 1 || index_to_remove > numel(array)
    error('Index out of bounds. Please provide a valid index.');
end

% Remove the specified index
modified_array = array;
modified_array(index_to_remove) = [];
end


