classdef escdf < handle
% ESCDF Container for one ESCDF file.
%
% An escdf object represents the in-memory contents of a single ESCDF HDF5
% file, including top-level metadata datasets, activity datasets, and
% file-level creation metadata.
%
% The container separates datasets into two conceptual groups:
%
% - metadata datasets, which describe shared context such as geometry,
%   channel tables, or global test attributes
% - activity datasets, which represent results associated with a specific
%   test, analysis step, or processing activity
%
% Parameters
% ----------
% None
%
% Notes
% -----
% When a new container is created, the created_by field is populated using
% escdf_get_or_prompt_attribution_name, which may prompt the user for an
% attribution name if one has not already been cached in the local ESCDF
% configuration file.
%
% See Also
% --------
% escdf_dataset
% escdf_activity
    properties (Access=private)
    end

    properties (Access = private)
        activities_array
        metadata_array
        created_by
        created_date
        lifecycle_state
        mutability_state
        backing_state
        has_pending_changes
    end

    properties (Dependent)
        activities
        metadata
    end

    methods
        function obj = escdf()
        % Create an empty ESCDF container.
        %
        % Notes
        % -----
        % A new container starts with no metadata datasets and no
        % activities. File-level creation metadata is initialized
        % immediately.
            obj.activities_array = escdf_activity.empty(1,0);
            obj.metadata_array = escdf_dataset.empty(1,0);
            obj.created_by = escdf.escdf_get_or_prompt_attribution_name();
            obj.created_date = datetime('now','TimeZone','UTC');

            obj.lifecycle_state = 'draft';
            obj.mutability_state = 'editable';
            obj.backing_state = 'memory';
            obj.has_pending_changes = false;
        end

        function out = get_created_by(obj)
        % Return the file-level creator attribution.
        %
        % Returns
        % -------
        % out : char
        %     Name or label recorded as the creator of the ESCDF file.
            out = obj.created_by;
        end

        function out = get_created_date(obj)
        % Return the file-level creation timestamp.
        %
        % Returns
        % -------
        % out : datetime
        %     Datetime recorded as the file creation time.
            out = obj.created_date;
        end

        function out = get_lifecycle_state(obj)
        % Return the container lifecycle state.
            out = obj.lifecycle_state;
        end

        function out = get_mutability_state(obj)
        % Return the container mutability state.
            out = obj.mutability_state;
        end

        function out = get_backing_state(obj)
        % Return the container backing state.
            out = obj.backing_state;
        end

        function out = get_has_pending_changes(obj)
        % Return whether the container has pending changes.
            out = obj.has_pending_changes;
        end

        function set_has_pending_changes(obj, tf)
        % Set the container pending-changes flag.
            obj.has_pending_changes = tf;
        end

        function set_created_properties(obj, created_by, created_date)
        % Set file-level creation metadata.
        %
        % Parameters
        % ----------
        % created_by : char or string
        %     Name or label to record as the file creator.
        % created_date : datetime, optional
        %     Creation timestamp to associate with the file. If omitted,
        %     the existing created_date value is retained.
        %
        % Raises
        % ------
        % error
        %     Raised if created_date is provided but is not a datetime
        %     object.
            if nargin == 2
                created_date = obj.created_date;
            end
            if isa(created_date,'datetime')
                obj.created_date = created_date;
            else
                error('created_date must be a datetime object')
            end
            obj.created_by = created_by;
            obj.has_pending_changes = true;
        end

        function add_activity(obj,short_name,descriptive_name,activity_date,data,metadata_links)
        % Add a new activity to the container.
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
        %     Initial activity result datasets to add to the activity.
        % metadata_links : cell array of char, optional
        %     Names of metadata datasets linked to this activity.
        %
        % Raises
        % ------
        % error
        %     Raised if an activity with the same name already exists, or
        %     if one of the metadata links does not correspond to an
        %     existing metadata dataset.
            if nargin < 5
                data = [];
            end
            if nargin < 6
                metadata_links = {};
            end
            if any(strcmp(obj.get_activity_names(),short_name))
                error(['Activity with name ',short_name,' already exists.'])
            end
            valid_metadata_names = obj.get_metadata_names();
            for i = 1:length(metadata_links)
                if ~any(strcmp(valid_metadata_names, metadata_links{i}))
                    error('Metadata link %s not found in metadata list', metadata_links{i});
                end
            end
            new_activity = escdf_activity(short_name,descriptive_name,activity_date,data,metadata_links);
            obj.activities_array(end+1) = new_activity;
            obj.has_pending_changes = true;
        end

        function add_metadata(obj,metadata,activity_to_link)
        % Add a metadata dataset to the container.
        %
        % Parameters
        % ----------
        % metadata : escdf_dataset
        %     Metadata dataset to add.
        % activity_to_link : char, optional
        %     Name of an activity that should be linked to the metadata
        %     immediately after insertion.
        %
        % Raises
        % ------
        % error
        %     Raised if the dataset name already exists in the metadata
        %     collection or if the linked activity name is invalid.
        %
        % Notes
        % -----
        % The supplied dataset is cloned into a new wrapper before
        % insertion so that the container owns its own dataset/property
        % wrapper objects.
            if nargin < 3
                activity_to_link = [];
            end

            if ~isa(metadata,'escdf_dataset')
                error('Added metadata must be an escdf_dataset object.')
            end

            metadata_to_add = obj.clone_dataset_for_attach(metadata);

            if any(strcmp(obj.get_metadata_names(),metadata_to_add.get_name()))
                error(['Metadata with name ',metadata_to_add.get_name(),' already exists.'])
            end
            obj.metadata_array(end+1) = metadata_to_add;

            if ~isempty(activity_to_link)
                index = obj.get_activity_index_from_name(activity_to_link);
                obj.activities(index).link_to_metadata(metadata_to_add.get_name());
            end
            obj.has_pending_changes = true;
        end

        function link_activity_to_metadata(obj,activity_name,metadata_name)
        % Link an activity to a metadata dataset.
        %
        % Parameters
        % ----------
        % activity_name : char
        %     Name of the activity to update.
        % metadata_name : char
        %     Name of the metadata dataset to link.
        %
        % Raises
        % ------
        % error
        %     Raised if metadata_name does not correspond to an existing
        %     metadata dataset.
            metadata_names = obj.get_metadata_names();
            if ~any(strcmp(metadata_names,metadata_name))
                error(['Name ',metadata_name,' does not correspond to any defined names of metadata.'])
            end
            activity_index = obj.get_activity_index_from_name(activity_name);
            if isempty(activity_index)
                error(['Name ',activity_name,' does not correspond to any defined names of activities.'])
            end
            activity = obj.activities(activity_index);
            activity.link_to_metadata(metadata_name)
            obj.has_pending_changes = true;
        end

        function unlink_activity_from_metadata(obj,activity_name,metadata_name)
        % Remove a metadata link from an activity.
        %
        % Parameters
        % ----------
        % activity_name : char
        %     Name of the activity to update.
        % metadata_name : char
        %     Name of the metadata dataset to unlink.
            metadata_names = obj.get_metadata_names();
            if ~any(strcmp(metadata_names,metadata_name))
                error(['Name ',metadata_name,' does not correspond to any defined names of metadata.'])
            end
            activity_index = obj.get_activity_index_from_name(activity_name);
            if isempty(activity_index)
                error(['Name ',activity_name,' does not correspond to any defined names of activities.'])
            end
            activity = obj.activities(activity_index);
            activity.unlink_from_metadata(metadata_name);
            obj.has_pending_changes = true;
        end

        function add_data_to_activity(obj, activity_name, data)
        % Add a result dataset to an activity.
        %
        % Parameters
        % ----------
        % activity_name : char
        %     Name of the activity to modify.
        % data : escdf_dataset
        %     Dataset to add to the activity.
        %
        % Notes
        % -----
        % The supplied dataset is cloned into a new wrapper before
        % insertion so that the activity/container owns its own
        % dataset/property wrapper objects.
            data_to_add = obj.clone_dataset_for_attach(data);
            activity = obj.get_activity_from_name(activity_name);
            activity.add_data(data_to_add);
            obj.has_pending_changes = true;
        end

        function removed = remove_data_from_activity(obj, activity_name, data_name)
        % Remove a dataset from an activity.
        %
        % Parameters
        % ----------
        % activity_name : char
        %     Name of the activity to modify.
        % data_name : char
        %     Name of the dataset to remove.
        %
        % Returns
        % -------
        % removed : escdf_dataset
        %     The removed dataset object.
        %
        % Notes
        % -----
        % This operation removes the dataset from the in-memory container
        % and activity graph only. It does not immediately delete any
        % underlying physical backing from disk.
            activity = obj.get_activity_from_name(activity_name);
            removed = activity.remove_data(data_name);
            obj.has_pending_changes = true;
        end

        function removed = remove_metadata(obj, metadata_name, unlink)
        % Remove a metadata dataset from the container.
        %
        % Parameters
        % ----------
        % metadata_name : char
        %     Name of the metadata dataset to remove.
        % unlink : logical, optional
        %     If true, automatically unlink the metadata from all
        %     activities before removing it. If false, raise an error if
        %     the metadata is still linked.
        %
        % Returns
        % -------
        % removed : escdf_dataset
        %     The removed metadata dataset object.
        %
        % Raises
        % ------
        % error
        %     Raised if no metadata dataset with the given name exists, or
        %     if the metadata is still linked and unlink is false.
        %
        % Notes
        % -----
        % This operation removes the metadata from the in-memory container
        % graph only. It does not immediately delete any underlying
        % physical backing from disk.
            if nargin < 3
                unlink = false;
            end

            index = obj.get_metadata_index_from_name(metadata_name);
            if isempty(index)
                error(['No metadata with name ', metadata_name])
            elseif length(index) > 1
                error(['Multiple metadata with name ', metadata_name, '. How did you get here?'])
            end

            linked_activities = obj.get_activities_linked_to_metadata(metadata_name);

            if ~isempty(linked_activities) && ~unlink
                error(['Metadata "', metadata_name, '" is still linked to activities ', ...
                    strjoin(linked_activities, ', '), '. Use unlink=true to remove those links automatically.'])
            end

            if unlink
                for i = 1:length(linked_activities)
                    obj.unlink_activity_from_metadata(linked_activities{i}, metadata_name);
                end
            end

            removed = obj.metadata(index);
            obj.metadata_array = escdf.remove_array_index(obj.metadata_array, index);
            obj.has_pending_changes = true;
        end

        function renamed = rename_metadata(obj, old_name, new_name)
        % Rename a metadata dataset in the container.
        %
        % Parameters
        % ----------
        % old_name : char
        %     Current metadata dataset name.
        % new_name : char
        %     New metadata dataset name.
        %
        % Returns
        % -------
        % renamed : escdf_dataset
        %     The renamed metadata dataset object.
        %
        % Raises
        % ------
        % error
        %     Raised if the old name does not exist, the new name already
        %     exists, or the new name is not a valid identifier.
        if ~(ischar(new_name) || isstring(new_name))
            error('New metadata name must be a string.');
        end
        new_name = char(string(new_name));

        if ~escdf.is_valid_identifier(new_name)
            error('New metadata name "%s" is not a valid identifier.', new_name);
        end

        index = obj.get_metadata_index_from_name(old_name);
        if isempty(index)
            error('No metadata dataset named "%s" exists.', old_name);
        elseif length(index) > 1
            error('Multiple metadata datasets named "%s" exist. How did you get here?', old_name);
        end

        if any(strcmp(obj.get_metadata_names(), new_name))
            error('A metadata dataset named "%s" already exists.', new_name);
        end

        renamed = obj.metadata(index);
        renamed.set_name(new_name);

        for i = 1:length(obj.activities)
            activity = obj.activities(i);
            links = activity.get_metadata_links();
            match = find(strcmp(links, old_name), 1);
            if ~isempty(match)
                activity.rename_metadata_link(old_name, new_name);
            end
        end

        obj.has_pending_changes = true;
        end

        function removed = replace_metadata(obj, metadata)
        % Replace a metadata dataset in the container.
        %
        % Parameters
        % ----------
        % metadata : escdf_dataset
        %     Replacement metadata dataset. Its name must match an
        %     existing metadata dataset in the container.
        %
        % Returns
        % -------
        % removed : escdf_dataset
        %     The removed metadata dataset object.
        %
        % Raises
        % ------
        % error
        %     Raised if no metadata dataset with the replacement name
        %     exists in the container.
        %
        % Notes
        % -----
        % This operation updates the in-memory logical graph only. It does
        % not immediately modify any physical HDF5 backing.
            if ~isa(metadata, 'escdf_dataset')
                error('Replacement metadata must be an escdf_dataset object.');
            end

            index = obj.get_metadata_index_from_name(metadata.get_name());
            if isempty(index)
                error('No metadata dataset named "%s" exists to replace.', metadata.get_name());
            elseif length(index) > 1
                error('Multiple metadata datasets named "%s" exist. How did you get here?', metadata.get_name());
            end

            removed = obj.metadata(index);
            metadata_to_add = obj.clone_dataset_for_attach(metadata);

            obj.metadata_array(index) = [];
            obj.metadata_array(end+1) = metadata_to_add;

            obj.has_pending_changes = true;
        end

        function removed = remove_activity(obj, activity_name, delete_unlinked_metadata)
        % Remove an activity from the container.
        %
        % Parameters
        % ----------
        % activity_name : char
        %     Name of the activity to remove.
        % delete_unlinked_metadata : logical, optional
        %     If true, also remove metadata datasets that were linked only
        %     to the removed activity and are not linked to any remaining
        %     activities afterward.
        %
        % Returns
        % -------
        % removed : escdf_activity
        %     The removed activity object.
        %
        % Raises
        % ------
        % error
        %     Raised if no activity with the given name exists.
        %
        % Notes
        % -----
        % This operation removes the activity from the in-memory container
        % graph only. It does not immediately delete any underlying
        % physical backing from disk.
            if nargin < 3
                delete_unlinked_metadata = false;
            end

            index = obj.get_activity_index_from_name(activity_name);
            if isempty(index)
                error(['No activity with name ', activity_name])
            elseif length(index) > 1
                error(['Multiple activities with name ', activity_name, '. How did you get here?'])
            end

            activity = obj.activities(index);
            linked_metadata = activity.get_metadata_links();

            removed = activity;
            obj.activities_array = escdf.remove_array_index(obj.activities_array, index);

            if delete_unlinked_metadata
                for i = 1:length(linked_metadata)
                    md = linked_metadata{i};
                    linked_activities = obj.get_activities_linked_to_metadata(md);
                    if isempty(linked_activities)
                        obj.remove_metadata(md, false);
                    end
                end
            end

            obj.has_pending_changes = true;
        end

        function renamed = rename_activity(obj, old_name, new_name)
        % Rename an activity in the container.
        %
        % Parameters
        % ----------
        % old_name : char
        %     Current activity name.
        % new_name : char
        %     New activity name.
        %
        % Returns
        % -------
        % renamed : escdf_activity
        %     The renamed activity object.
        %
        % Raises
        % ------
        % error
        %     Raised if the old name does not exist, the new name already
        %     exists, or the new name is not a valid identifier.
            if ~(ischar(new_name) || isstring(new_name))
                error('New activity name must be a string.');
            end
            new_name = char(string(new_name));

            if ~escdf.is_valid_identifier(new_name)
                error('New activity name "%s" is not a valid identifier.', new_name);
            end

            index = obj.get_activity_index_from_name(old_name);
            if isempty(index)
                error('No activity named "%s" exists.', old_name);
            elseif length(index) > 1
                error('Multiple activities named "%s" exist. How did you get here?', old_name);
            end

            if any(strcmp(obj.get_activity_names(), new_name))
                error('An activity named "%s" already exists.', new_name);
            end

            renamed = obj.activities(index);
            renamed.set_name(new_name);
            renamed.set_has_pending_changes(true);
            obj.has_pending_changes = true;
        end

        function data = get_activity_data(obj,activity_name,data_name)
        % Retrieve one or more datasets from an activity.
        %
        % Parameters
        % ----------
        % activity_name : char
        %     Name of the activity to query.
        % data_name : char, optional
        %     Name of a specific dataset within the activity. If omitted,
        %     all datasets in the activity are returned.
        %
        % Returns
        % -------
        % data : escdf_dataset or escdf_dataset array
        %     Requested dataset, or all datasets in the activity.
            if nargin<3
                data_name = [];
            end
            activity = obj.get_activity_from_name(activity_name);
            if isempty(data_name)
                data = activity.get_all_data();
            else
                data = activity.get_data(data_name);
            end
        end

        function renamed = rename_activity_data(obj, activity_name, old_name, new_name)
        % Rename a dataset within an activity.
        %
        % Parameters
        % ----------
        % activity_name : char
        %     Name of the activity to modify.
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
        % Notes
        % -----
        % This is a convenience wrapper around the activity-level
        % rename_data operation.
            activity = obj.get_activity_from_name(activity_name);
            renamed = activity.rename_data(old_name, new_name);
            obj.has_pending_changes = true;
        end

        function removed = replace_data_in_activity(obj, activity_name, data)
        % Replace a dataset within an activity.
        %
        % Parameters
        % ----------
        % activity_name : char
        %     Name of the activity to modify.
        % data : escdf_dataset
        %     Replacement dataset. Its name must match an existing dataset
        %     in the activity.
        %
        % Returns
        % -------
        % removed : escdf_dataset
        %     The removed dataset object.
        %
        % Notes
        % -----
        % This operation updates the in-memory container/activity graph
        % only. It does not immediately modify any physical HDF5 backing.
            activity = obj.get_activity_from_name(activity_name);
            data_to_add = obj.clone_dataset_for_attach(data);
            removed = activity.replace_data(data_to_add);
            obj.has_pending_changes = true;
        end

        function value = get.activities(obj)
            value = obj.activities_array;
        end

        function value = get.metadata(obj)
            value = obj.metadata_array;
        end

        function disp(obj)
            fprintf('%s\n\n',obj.repr())
        end

        function out = repr_activities(obj)
            out = obj.activities.repr();
        end

        function out = repr(obj)
            metadata_list = sort(obj.get_metadata_names());
            out = sprintf('\n  escdf object\n    Created by %s on %s\n\n  Metadata:\n',obj.created_by, obj.created_date);
            for i = 1:length(metadata_list)
                metadata_name = metadata_list{i};
                metadata = obj.get_metadata_from_name(metadata_name);
                out = [out,sprintf('\n    %s (%s)',metadata_name,metadata.get_type())];
            end
            out = [out,sprintf('\n\n  Activities:\n')];
            out = [out,obj.repr_activities()];
        end

        function metadata = get_activity_metadata(obj,activity_name)
        % Retrieve metadata datasets linked to an activity.
        %
        % Parameters
        % ----------
        % activity_name : char
        %     Name of the activity to query.
        %
        % Returns
        % -------
        % metadata : escdf_dataset array
        %     Metadata datasets linked to the activity.
            metadata = escdf_dataset.empty(1,0);
            activity = obj.get_activity_from_name(activity_name);
            metadata_names = activity.get_metadata_links();
            for i = 1:length(metadata_names)
                metadata(end+1) = obj.get_metadata_from_name(metadata_names{i});
            end
        end

        function metadata = get_metadata(obj,name)
            if nargin < 2
                metadata = obj.metadata;
            else
                metadata = obj.get_metadata_from_name(name);
            end
        end

        function activity = get_activity(obj,name)
            if nargin < 2
                activity = obj.activities;
            else
                activity = obj.get_activity_from_name(name);
            end
        end

        function cloned = clone_property_for_attach(obj, property) %#ok<INUSD>
        % Clone a property wrapper for attachment into a new container.
        %
        % Parameters
        % ----------
        % property : escdf_property
        %     Source property to clone.
        %
        % Returns
        % -------
        % cloned : escdf_property
        %     New property wrapper suitable for attachment into a new
        %     dataset/container context.
        %
        % Notes
        % -----
        % First-pass behavior:
        %
        % - memory-backed properties are eagerly copied into new in-memory
        %   property wrappers
        % - hdf5_native properties are wrapped as hdf5_external in the
        %   clone
        % - hdf5_external properties remain externally backed in the clone
            backing_state = property.get_backing_state();

            if strcmp(backing_state, 'memory')
                cloned = escdf_property( ...
                    property.get_name(), ...
                    property.get_format(), ...
                    property.get_size(), ...
                    'ragged', property.isragged());
                cloned(:) = property(:);
                return
            end

            if strcmp(backing_state, 'hdf5_native') || strcmp(backing_state, 'hdf5_external')
                source_dataset_id = property.get_h5d_id();
                dataset_path = H5I.get_name(source_dataset_id);
                file_id = H5I.get_file_id(source_dataset_id);
                cloned_dataset_id = H5D.open(file_id, dataset_path);

                cloned = escdf_property.load(cloned_dataset_id);
                cloned.mark_external_backing();
                return
            end

            error('Unknown property backing_state "%s" for property %s.', ...
                backing_state, property.get_name());
        end

        function cloned = clone_dataset_for_attach(obj, dataset) %#ok<INUSD>
        % Clone a dataset wrapper for attachment into a new container.
        %
        % Parameters
        % ----------
        % dataset : escdf_dataset
        %     Source dataset to clone.
        %
        % Returns
        % -------
        % cloned : escdf_dataset
        %     New dataset wrapper suitable for insertion into a different
        %     container.
        %
        % Notes
        % -----
        % This is a first-pass shallow-semantic clone of the dataset
        % wrapper, with per-property handling delegated to
        % clone_property_for_attach.
            cloned = escdf_dataset( ...
                dataset.get_name(), ...
                dataset.get_type(), ...
                dataset.get_descriptive_name(), ...
                false);

            version_numbers = dataset.get_version_numbers();
            cloned.set_version(version_numbers(1), version_numbers(2), version_numbers(3));

            property_names = properties(dataset);
            for i = 1:length(property_names)
                property_name = property_names{i};

                % Skip hidden storage properties
                if startsWith(property_name, 'DO_NOT_USE_')
                    continue
                end

                try
                    property_value = dataset.(property_name);
                catch
                    continue
                end

                if isempty(property_value)
                    continue
                end

                % If the source dataset has a noncanonical dynamic property,
                % mirror that dynamic property on the clone.
                clone_properties = properties(cloned);
                if ~ismember(property_name, clone_properties)
                    hidden_prop = addprop(cloned, ['DO_NOT_USE_', property_name]);
                    hidden_prop.Hidden = true;

                    user_prop = addprop(cloned, property_name);
                    user_prop.SetMethod = @(obj,val) escdf_dataset.set_dynamic_prop(property_name,obj,val);
                    user_prop.GetMethod = @(obj) escdf_dataset.get_dynamic_prop(property_name,obj);

                    cloned.has_modified_properties = true;
                end

                cloned_property = obj.clone_property_for_attach(property_value);
                cloned.(property_name) = cloned_property;
            end

            if dataset.get_has_modified_properties()
                cloned.has_modified_properties = true;
            end

            cloned.set_backing_state('memory');
            cloned.set_has_pending_changes(false);
        end

        function insert_metadata_native(obj, metadata, activity_to_link)
        % Insert a metadata dataset into the container without cloning.
        %
        % Parameters
        % ----------
        % metadata : escdf_dataset
        %     Metadata dataset to insert directly.
        % activity_to_link : char, optional
        %     Name of an activity to link to the metadata immediately after
        %     insertion.
        %
        % Notes
        % -----
        % This is intended for internal use during file loading, where the
        % loaded dataset already belongs natively to the container being
        % constructed.
            if nargin < 3
                activity_to_link = [];
            end

            if ~isa(metadata,'escdf_dataset')
                error('Added metadata must be an escdf_dataset object.')
            end
            if any(strcmp(obj.get_metadata_names(),metadata.get_name()))
                error(['Metadata with name ',metadata.get_name(),' already exists.'])
            end
            obj.metadata_array(end+1) = metadata;
            if ~isempty(activity_to_link)
                index = obj.get_activity_index_from_name(activity_to_link);
                obj.activities(index).link_to_metadata(metadata.get_name());
            end
            obj.has_pending_changes = true;
        end

        function insert_data_to_activity_native(obj, activity_name, data)
        % Insert a dataset into an activity without cloning.
        %
        % Parameters
        % ----------
        % activity_name : char
        %     Name of the target activity.
        % data : escdf_dataset
        %     Dataset to insert directly.
        %
        % Notes
        % -----
        % This is intended for internal use during file loading, where the
        % loaded dataset already belongs natively to the container being
        % constructed.
            activity = obj.get_activity_from_name(activity_name);
            activity.add_data(data);
            obj.has_pending_changes = true;
        end

        function file_id = write_to_disk(obj,file_path,clobber)
        % Write the container to an HDF5 file.
        %
        % Parameters
        % ----------
        % file_path : char
        %     Output HDF5 file path.
        % clobber : logical, optional
        %     If true, overwrite an existing file. If false, require that
        %     the file not already exist.
        %
        % Returns
        % -------
        % file_id : numeric
        %     HDF5 file identifier for the written file.
        %
        % Raises
        % ------
        % error
        %     Raised if any metadata or activity dataset fails validation
        %     before writing.
        %
        % Notes
        % -----
        % All contained datasets are validated before any HDF5 content is
        % written.
            if nargin < 3
                clobber = false;
            end
            % First go through and make sure all datasets are valid.
            for i = 1:length(obj.metadata)
                md = obj.metadata(i);
                isvalid = md.validate();
                if ~isvalid
                    error(['Cannot write file to disk.  Metadata ',md.get_name(),' is invalid.'])
                end
            end
            % Now go through all activities and all data in all activities
            % to make sure everything is valid.
            for i = 1:length(obj.activities)
                activity = obj.activities(i);
                activity_data = activity.get_data();
                for j = 1:length(activity_data)
                    data = activity_data(j);
                    isvalid = data.validate();
                    if ~isvalid
                        error(['Cannot write file to disk.  Data ',data.get_name(),' from activity ',activity.get_name(),' is invalid.'])
                    end
                end
            end
            if clobber
                file_id = H5F.create(file_path,'H5F_ACC_TRUNC','H5P_DEFAULT','H5P_DEFAULT');
            else
                file_id = H5F.create(file_path,'H5F_ACC_EXCL','H5P_DEFAULT','H5P_DEFAULT');
            end
            % Add user name and date
            attr_space_id = H5S.create('H5S_SCALAR');
            str_type_id = H5T.copy('H5T_C_S1');
            H5T.set_size(str_type_id, 'H5T_VARIABLE');
            attr_id = H5A.create(file_id, 'created_by', str_type_id, attr_space_id, 'H5P_DEFAULT');
            H5A.write(attr_id,str_type_id, obj.created_by);
            H5A.close(attr_id);
            H5T.close(str_type_id);
            H5S.close(attr_space_id);
            attr_space_id = H5S.create('H5S_SCALAR');
            str_type_id = H5T.copy('H5T_C_S1');
            H5T.set_size(str_type_id, 'H5T_VARIABLE');
            attr_id = H5A.create(file_id, 'created_date', str_type_id, attr_space_id, 'H5P_DEFAULT');
            H5A.write(attr_id,str_type_id,escdf.datetime_to_iso_utc(obj.created_date));
            H5A.close(attr_id);
            H5T.close(str_type_id);
            H5S.close(attr_space_id);
            for i = 1:length(obj.metadata)
                md = obj.metadata(i);
                gid = H5G.create(file_id,md.get_name(), 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');
                md.write_to_disk(gid);
                H5G.close(gid)
            end
            agid = H5G.create(file_id,'activities', 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');
            obj.activities.write_to_disk(agid);
            H5G.close(agid);
            obj.backing_state = 'hdf5_native';
            obj.has_pending_changes = false;
        end

        function varargout = subsref(obj, S)
            if strcmp(S(1).type,'.') && length(S) > 1 && strcmp(S(1).subs,'metadata') && strcmp(S(2).type,'.')
                metadata_names = {};
                metadata = obj.metadata;
                for i = 1:numel(metadata)
                    metadata_names{end+1} = metadata(i).get_name();
                end
                metadata_index = find(strcmp(metadata_names,S(2).subs));
                if isempty(metadata_index)
                    [varargout{1:nargout}] = builtin('subsref', obj, S);
                else
                    if length(S) == 2
                        varargout{1} = metadata(metadata_index);
                    else
                        [varargout{1:nargout}] = subsref(metadata(metadata_index),S(3:end));
                    end
                end
            else
                [varargout{1:nargout}] = builtin('subsref', obj, S);
            end
        end

        function out = dump_to_struct(obj)
            out = struct('metadata',[],'activities',[]);
            for i = 1:length(obj.metadata)
                this_metadata = obj.metadata(i);
                metadata_name = this_metadata.get_name();
                out.metadata.(metadata_name) = [];
                metadata_properties = properties(this_metadata);
                for j = 1:length(metadata_properties)
                    this_property_name = metadata_properties{j};
                    this_property = this_metadata.(this_property_name);
                    out.metadata.(metadata_name).(this_property_name) = this_property(:);
                end
                out.metadata.(metadata_name).ESCDF_DATASET_TYPE = this_metadata.get_type();
                out.metadata.(metadata_name).ESCDF_DATASET_DESCRIPTIVE_NAME = this_metadata.get_descriptive_name();
            end
            for i = 1:length(obj.activities)
                this_activity = obj.activities(i);
                activity_name = this_activity.get_name();
                out.activities.(activity_name) = [];
                data = this_activity.get_data();
                for j = 1:length(data)
                    this_data = data(j);
                    data_name = this_data.get_name();
                    out.activities.(activity_name).(data_name) = [];
                    data_properties = properties(this_data);
                    for k = 1:length(data_properties)
                        this_property_name = data_properties{k};
                        this_property = this_data.(this_property_name);
                        out.activities.(activity_name).(data_name).(this_property_name) = this_property(:);
                    end
                    out.activities.(activity_name).(data_name).ESCDF_DATASET_TYPE = this_data.get_type();
                    out.activities.(activity_name).(data_name).ESCDF_DATASET_DESCRIPTIVE_NAME = this_data.get_descriptive_name();
                end
                out.activities.(activity_name).ESCDF_METADATA_LINKS = this_activity.get_metadata_links();
                out.activities.(activity_name).ESCDF_ACTIVITY_DESCRIPTION = this_activity.get_descriptive_name();
                out.activities.(activity_name).ESCDF_ACTIVITY_DATE = this_activity.get_date();
            end
        end

    end

    methods (Access = private)
        function names = get_metadata_names(obj)
            names = arrayfun(@(x) x.get_name(),obj.metadata,'UniformOutput',false);
        end

        function names = get_activity_names(obj)
            names = arrayfun(@(x) x.get_name(),obj.activities,'UniformOutput',false);
        end

        function index = get_metadata_index_from_name(obj,name)
            names = obj.get_metadata_names();
            index = find(strcmp(names,name));
        end

        function index = get_activity_index_from_name(obj,name)
            names = obj.get_activity_names();
            index = find(strcmp(names,name));
        end

        function activity_names = get_activities_linked_to_metadata(obj,metadata_name)
            activity_names = {};
            for i = 1:length(obj.activities)
                activity = obj.activities(i);
                if any(strcmp(activity.get_metadata_links(),metadata_name))
                    activity_names{end+1} = activity.get_name();
                end
            end
        end

        function activity = get_activity_from_name(obj,name)
            index = obj.get_activity_index_from_name(name);
            if length(index) > 1
                error(['Multiple activities with name ',name, '.  How did you get here?'])
            elseif isempty(index)
                error(['No activity with name ',name])
            end
            activity = obj.activities(index);
        end

        function metadata = get_metadata_from_name(obj,name)
            index = obj.get_metadata_index_from_name(name);
            if length(index) > 1
                error(['Multiple metadata with name ',name, '.  How did you get here?'])
            elseif isempty(index)
                error(['No metadata with name ',name])
            end
            metadata = obj.metadata(index);
        end

    end

    methods (Static)
        function escdf_file = load(hdf5_path,readonly)
        % Load an ESCDF container from an HDF5 file.
        %
        % Parameters
        % ----------
        % hdf5_path : char or string
        %     Input HDF5 file path.
        % readonly : logical, optional
        %     If true, open the file read-only. If false, open read/write.
        %
        % Returns
        % -------
        % escdf_file : escdf
        %     Loaded ESCDF container.
        %
        % Notes
        % -----
        % Unknown dataset types are loaded using the unknown
        % specification. Invalid identifiers encountered on disk may be
        % repaired during loading to produce valid in-memory dataset and
        % activity names.
            if nargin < 2
                readonly = true;
            end
            if isstring(hdf5_path)
                hdf5_path = char(hdf5_path);
            end
            escdf_file = escdf();
            % Get the datasets and groups in the file
            [group_names, ~] = escdf.get_groups_and_datasets(hdf5_path,'/');
            metadata_names = group_names(~strcmp(group_names,'activities'));
            [activity_names,dataset_names] = escdf.get_groups_and_datasets(hdf5_path,'/activities');
            try
                created_by = h5readatt(hdf5_path,'/','created_by');
            catch
                warning('Unable to read created_by field.  Setting to "UNKNOWN".');
                created_by = 'UNKNOWN';
            end
            try
                created_date_raw = h5readatt(hdf5_path, '/', 'created_date');
                created_date = escdf.datetime_from_iso_utc(created_date_raw);
            catch
                warning('Unable to read created_date field.  Setting to 01-Jan-1900.');
                created_date = datetime([1900,1,1],'TimeZone','UTC');
            end
            escdf_file.set_created_properties(created_by, created_date);
            for i = 1:length(metadata_names)
                metadata_name = metadata_names{i};
                dataset = escdf_dataset.load([hdf5_path,'::/',metadata_name],readonly);
                escdf_file.insert_metadata_native(dataset);
            end

            for i = 1:length(activity_names)
                activity_name = activity_names{i};
                long_name = h5readatt(hdf5_path,['/activities/',activity_name],'activity_name');
                try
                    activity_date_raw = h5readatt(hdf5_path, ['/activities/', activity_name], 'activity_date');
                    date = escdf.datetime_from_iso_utc(activity_date_raw);
                catch
                    date = datetime([1900,1,1],'TimeZone','UTC');
                    try
                        warning(sprintf('Unable to convert %s to datetime using ISO format.  Setting date to 01-Jan-1900 for activity %s.',...
                            h5readatt(hdf5_path,['/activities/',activity_name],'activity_date'), activity_name));
                    catch
                        warning(sprintf('Unable to parse activity_date for activity %s.  Setting date to 01-Jan-1900.',...
                            activity_name));
                    end
                end
                name_valid = escdf.is_valid_identifier(activity_name);
                if (~name_valid)
                    valid_activity_name = escdf.make_valid_identifier(activity_name, 'activity_');
                else
                    valid_activity_name = activity_name;
                end
                escdf_file.add_activity(valid_activity_name,long_name,date);
                links = h5read(hdf5_path,['/activities/',activity_name,'/parameters']);
                for j = 1:length(links)
                    link = links{j};
                    name_valid = escdf.is_valid_identifier(link);
                    if ~name_valid
                        link = escdf.make_valid_identifier(link,'dataset_');
                    end
                    escdf_file.link_activity_to_metadata(valid_activity_name,link);
                end
                [activity_data_names,activity_dataset_names] = escdf.get_groups_and_datasets(hdf5_path,['/activities/',activity_name]);
                for j = 1:length(activity_data_names)
                    activity_data_name = activity_data_names{j};
                    dataset = escdf_dataset.load([hdf5_path,'::/activities/',activity_name,'/',activity_data_name],readonly);
                    escdf_file.insert_data_to_activity_native(valid_activity_name,dataset);
                end

                loaded_activity = escdf_file.get_activity(valid_activity_name);
                loaded_activity.set_backing_state('hdf5_native');
                loaded_activity.set_has_pending_changes(false);
            end
            escdf_file.backing_state = 'hdf5_native';
            escdf_file.lifecycle_state = 'draft';
            if readonly
                escdf_file.mutability_state = 'read_only';
            else
                escdf_file.mutability_state = 'editable';
            end
            escdf_file.has_pending_changes = false;
        end

        function escdf_file = build_from_struct(structure)
            escdf_file = escdf();
            metadata_field_names = fields(structure.metadata);
            for i = 1:length(metadata_field_names)
                metadata_field_name = metadata_field_names{i};
                metadata_type = structure.metadata.(metadata_field_name).ESCDF_DATASET_TYPE;
                this_metadata = escdf_dataset(metadata_field_name,metadata_type);
                dataset_property_names = fields(structure.metadata.(metadata_field_name));
                for j = 1:length(dataset_property_names)
                    dataset_property_name = dataset_property_names{j};
                    if strcmp(dataset_property_name,'ESCDF_DATASET_TYPE')
                        continue
                    end
                    if ~isempty(structure.metadata.(metadata_field_name).(dataset_property_name))
                        this_metadata.(dataset_property_name) = structure.metadata.(metadata_field_name).(dataset_property_name);
                    end
                end
                escdf_file.add_metadata(this_metadata);
            end
            activity_field_names = fields(structure.activities);
            for i = 1:length(activity_field_names)
                activity_field_name = activity_field_names{i};
                date = structure.activities.(activity_field_name).ESCDF_ACTIVITY_DATE;
                descriptive_name = structure.activities.(activity_field_name).ESCDF_ACTIVITY_DESCRIPTION;
                escdf_file.add_activity(activity_field_name,descriptive_name,date);
                data_field_names = fields(structure.activities.(activity_field_name));
                for j = 1:length(data_field_names)
                    data_field_name = data_field_names{j};
                    if strcmp(data_field_name,'ESCDF_METADATA_LINKS')
                        continue
                    end
                    data_type = structure.activities.(activity_field_name).(data_field_name).ESCDF_DATASET_TYPE;
                    this_data = escdf_dataset(data_field_name,data_type);
                    dataset_property_names = fields(structure.activities.(activity_field_name).(data_field_name));
                    for k = 1:length(dataset_property_names)
                        dataset_property_name = dataset_property_names{k};
                        if strcmp(dataset_property_name,'ESCDF_DATASET_TYPE')
                            continue
                        end
                        if ~isempty(structure.activities.(activity_field_name).(data_field_name).(dataset_property_name))
                            this_data.(dataset_property_name) = structure.activities.(activity_field_name).(data_field_name).(dataset_property_name);
                        end
                    end
                    escdf_file.add_data_to_activity(activity_field_name,this_data);
                end
                for j = 1:length(structure.activities.(activity_field_name).ESCDF_METADATA_LINKS)
                    escdf_file.link_activity_to_metadata(activity_field_name,structure.activities.(activity_field_name).ESCDF_METADATA_LINKS{j})
                end
            end
        end

        function [groups, datasets] = get_groups_and_datasets(filePath, internalPath)
        % Return group and dataset names contained in an HDF5 group.
        %
        % Parameters
        % ----------
        % filePath : char or numeric
        %     HDF5 file path or open file identifier.
        % internalPath : char
        %     Group path within the HDF5 file.
        %
        % Returns
        % -------
        % groups : cell array of char
        %     Names of child groups in the requested HDF5 group.
        % datasets : cell array of char
        %     Names of child datasets in the requested HDF5 group.
            % Check if the input is a file path or file ID
            if ischar(filePath)
                % Open the HDF5 file
                fileId = H5F.open(filePath, 'H5F_ACC_RDONLY', 'H5P_DEFAULT');
                closeFile = true;
            else
                % Use the provided file ID
                fileId = filePath;
                closeFile = false;
            end

            % Open the specified group
            groupId = H5G.open(fileId, internalPath);

            % Initialize output variables
            groups = {};
            datasets = {};

            % Get the number of objects in the group
            info = H5G.get_info(groupId);
            numObjs = info.nlinks;

            % Iterate over the objects in the group
            for idx = 0:numObjs-1
                % Get the name of the object
                objName = H5G.get_objname_by_idx(groupId, idx);

                % Get the type of the object
                objType = H5G.get_objtype_by_idx(groupId, idx);

                % Check the type and add to the appropriate list
                if objType == H5ML.get_constant_value('H5G_GROUP')
                    groups{end+1} = objName; %#ok<AGROW>
                elseif objType == H5ML.get_constant_value('H5G_DATASET')
                    datasets{end+1} = objName; %#ok<AGROW>
                end
            end

            % Close the group
            H5G.close(groupId);

            % Close the file if it was opened in this function
            if closeFile
                H5F.close(fileId);
            end
        end

        function is_valid = is_valid_identifier(identifier)
        % Check whether a name is a valid ESCDF identifier.
        %
        % Parameters
        % ----------
        % identifier : char
        %     Identifier string to validate.
        %
        % Returns
        % -------
        % is_valid : logical
        %     True if the identifier starts with a letter and contains only
        %     letters, digits, and underscores.
            pattern = '^[a-zA-Z][a-zA-Z0-9_]*$';
            is_valid = ~isempty(regexp(identifier, pattern, 'once'));
        end

        function valid_identifier = make_valid_identifier(identifier, prefix)
        % Convert a string into a valid ESCDF identifier.
        %
        % Parameters
        % ----------
        % identifier : char
        %     Identifier string to transform.
        % prefix : char
        %     Prefix to apply if the transformed identifier still does not
        %     begin with a letter.
        %
        % Returns
        % -------
        % valid_identifier : char
        %     Valid ESCDF identifier produced from the input string.
        %
        % Notes
        % -----
        % Whitespace is converted to underscores and invalid characters are
        % removed.
            % Replace whitespace with underscores
            original_identifier = identifier;
            identifier = regexprep(identifier, '\s+', '_');

            % Remove invalid characters (anything not a letter, number, or underscore)
            identifier = regexprep(identifier, '[^a-zA-Z0-9_]', '');

            % Check if the identifier is valid
            if isempty(regexp(identifier, '^[a-zA-Z][a-zA-Z0-9_]*$', 'once'))
                identifier = [prefix identifier];
            end
            if ~strcmp(identifier, original_identifier)
                warning('Replaced name %s with name %s', original_identifier, identifier)
            end

            valid_identifier = identifier;
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

        function name = escdf_get_or_prompt_attribution_name(interactive)
        % Return the configured attribution name or prompt the user for one.
        %
        % Parameters
        % ----------
        % interactive : logical, optional
        %     If true, prompt the user when no cached attribution name is
        %     available. If false, raise an error instead of prompting.
        %
        % Returns
        % -------
        % name : string
        %     Attribution name to record in newly created files.
        %
        % Raises
        % ------
        % error
        %     Raised if no attribution name is configured and interactive
        %     prompting is disabled.
        %
        % Notes
        % -----
        % When a name is entered interactively, it is stored in the local
        % ESCDF configuration file for future use.

            if nargin < 1, interactive = true; end

            cfgPath = escdf.escdf_config_path();
            cfg = escdf.escdf_load_config(cfgPath);

            name = "";
            if isfield(cfg, 'attribution_name') && ~isempty(strtrim(string(cfg.attribution_name)))
                name = strtrim(string(cfg.attribution_name));
                return
            end

            if ~interactive
                error("ESCDF:NoAttributionName", ...
                    "No attribution_name configured and interactive prompting is disabled. " + ...
                    "Create %s with an 'attribution_name' field, or pass a name explicitly.", cfgPath);
            end

            prompt = sprintf(['Enter the data creator''s user name to record in files.\n', ...
                'Examples: "Dan Rohe", "dprohe", "TAIII Vibration":']);
            name = escdf.escdf_prompt_string(prompt);

            name = strtrim(string(name));
            if strlength(name) == 0
                name = "anonymous";
            end

            cfg.attribution_name = char(name);
            cfg.schema_version = 1;
            cfg.updated_utc = char(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'"));

            escdf.escdf_save_config(cfgPath, cfg);
        end


        function cfgPath = escdf_config_path()
        % Return the platform-specific ESCDF configuration file path.
        %
        % Returns
        % -------
        % cfgPath : char
        %     Path to the JSON configuration file used to cache the
        %     attribution name and related metadata.
            libDisplayName = 'ESCDF';
            libId = 'escdf';

            if ispc
                base = getenv('APPDATA'); % Roaming
                if isempty(base)
                    base = char(java.lang.System.getProperty('user.home'));
                end
                cfgPath = fullfile(base, libDisplayName, 'config.json');

            elseif ismac
                home = char(java.lang.System.getProperty('user.home'));
                cfgPath = fullfile(home, 'Library', 'Application Support', libDisplayName, 'config.json');

            else
                xdg = getenv('XDG_CONFIG_HOME');
                home = char(java.lang.System.getProperty('user.home'));
                if isempty(xdg)
                    base = fullfile(home, '.config');
                else
                    base = xdg;
                end
                cfgPath = fullfile(base, libId, 'config.json');
            end
        end

        function cfg = escdf_load_config(cfgPath)
        % Load the local ESCDF JSON configuration file.
        %
        % Parameters
        % ----------
        % cfgPath : char
        %     Configuration file path.
        %
        % Returns
        % -------
        % cfg : struct
        %     Parsed configuration struct. If the configuration file does
        %     not exist or cannot be read, an empty struct is returned.
            cfg = struct();
            if ~isfile(cfgPath), return; end

            try
                txt = fileread(cfgPath);
                cfg = jsondecode(txt);
            catch
                % Treat unreadable/corrupt as missing; alternatively, rethrow.
                cfg = struct();
            end
        end


        function escdf_save_config(cfgPath, cfg)
        % Save the local ESCDF JSON configuration file.
        %
        % Parameters
        % ----------
        % cfgPath : char
        %     Configuration file path.
        % cfg : struct
        %     Configuration struct to serialize.
        %
        % Notes
        % -----
        % The file is written via a temporary file and then moved into
        % place to reduce the chance of partially written configuration
        % files.
            cfgDir = fileparts(cfgPath);
            if ~isfolder(cfgDir)
                mkdir(cfgDir);
            end

            txt = jsonencode(cfg, 'PrettyPrint', true);

            % Atomic-ish write: write to temp then move/replace
            tmpPath = cfgPath + ".tmp";
            fid = fopen(tmpPath, 'w');
            if fid < 0
                error("ESCDF:IO", "Cannot write config file: %s", tmpPath);
            end
            cleanup = onCleanup(@() fclose(fid));
            fwrite(fid, txt, 'char');
            fwrite(fid, newline, 'char');
            clear cleanup

            if isfile(cfgPath)
                delete(cfgPath); % Windows movefile behavior can be finicky if dest exists
            end
            movefile(tmpPath, cfgPath, 'f');
        end


        function s = escdf_prompt_string(prompt)
        % Prompt the user for a string value.
        %
        % Parameters
        % ----------
        % prompt : char
        %     Prompt text to display.
        %
        % Returns
        % -------
        % s : char
        %     User-supplied string.
        %
        % Raises
        % ------
        % error
        %     Raised if the user cancels the dialog-based prompt.
        %
        % Notes
        % -----
        % If a desktop session is available, an input dialog is used.
        % Otherwise, prompting falls back to the command window.
            % Use inputdlg if available; otherwise fall back to command line input.
            useDlg = usejava('desktop') && ~ismcc && ~isdeployed; % typical heuristic

            if useDlg
                answer = inputdlg({prompt}, 'ESCDF attribution', 1, {''});
                if isempty(answer)
                    error("ESCDF:UserCancelled","User cancelled attribution entry.");
                end
                s = answer{1};
            else
                fprintf('%s\n', prompt);
                s = input('> ', 's');
            end
        end

        function s = datetime_to_iso_utc(dtin)
        % Convert a datetime value to canonical ISO UTC text.
        %
        % Parameters
        % ----------
        % dtin : datetime
        %     Datetime value to convert.
        %
        % Returns
        % -------
        % s : char
        %     ISO 8601 UTC timestamp string in the form
        %     yyyy-MM-ddTHH:mm:ss.SSSSSSZ.
        %
        % Raises
        % ------
        % error
        %     Raised if dtin is not a datetime object.
        %
        % Notes
        % -----
        % Naive datetimes are assumed to be UTC and generate a warning.
            if ~isa(dtin, 'datetime')
                error('ESCDF:InvalidDatetime', 'Input must be a datetime object.');
            end
        
            % If timezone is not set, assume UTC
            if isempty(dtin.TimeZone)
                warning('ESCDF:NaiveDatetime', ...
                    'Datetime has no TimeZone defined; assuming UTC.');
                dtin.TimeZone = 'UTC';
            else
                dtin.TimeZone = 'UTC';
            end
        
            s = char(dtin, "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'");
        end

        function dtout = datetime_from_iso_utc(s)
        % Parse an ISO timestamp string as a UTC datetime.
        %
        % Parameters
        % ----------
        % s : char or string
        %     Timestamp string to parse.
        %
        % Returns
        % -------
        % dtout : datetime
        %     Parsed datetime value with TimeZone set to UTC.
        %
        % Raises
        % ------
        % error
        %     Raised if the timestamp string cannot be parsed.
        %
        % Notes
        % -----
        % Canonical ESCDF timestamps use UTC with a trailing Z. Several
        % older formats are accepted for backward compatibility.
            if isstring(s)
                s = char(s);
            end
        
            % Canonical form with microseconds and Z
            try
                dtout = datetime(s, ...
                    'InputFormat', "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'", ...
                    'TimeZone', 'UTC');
                return
            catch
            end
        
            % Backward compatibility: no fractional seconds, with Z
            try
                dtout = datetime(s, ...
                    'InputFormat', "yyyy-MM-dd'T'HH:mm:ss'Z'", ...
                    'TimeZone', 'UTC');
                return
            catch
            end
        
            % Backward compatibility: legacy no-Z format
            try
                dtout = datetime(s, ...
                    'InputFormat', "yyyy-MM-dd'T'HH:mm:ss", ...
                    'TimeZone', 'UTC');
                warning('ESCDF:NaiveDatetimeString', ...
                    'Datetime string "%s" has no timezone information; assuming UTC.', s);
                return
            catch
            end
        
            % Backward compatibility: maybe fractional but no Z
            try
                dtout = datetime(s, ...
                    'InputFormat', "yyyy-MM-dd'T'HH:mm:ss.SSSSSS", ...
                    'TimeZone', 'UTC');
                warning('ESCDF:NaiveDatetimeString', ...
                    'Datetime string "%s" has no timezone information; assuming UTC.', s);
                return
            catch
            end
        
            error('ESCDF:InvalidDatetimeString', ...
                'Could not parse datetime string: %s', s);
        end

    end

end