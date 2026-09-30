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
            if isa(activity_date,'datetime')
                obj.activity_date = activity_date;
            else
                error('activity_date must be a datetime object')
            end
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
            obj.data = [obj.data,dataset];
        end

        function remove_data(obj,dataset_name)
        % Remove a dataset from the activity.
        %
        % Parameters
        % ----------
        % dataset_name : char
        %     Name of the dataset to remove.
        %
        % Raises
        % ------
        % error
        %     Raised if no dataset with the requested name exists in the
        %     activity.
            index = obj.get_data_index_from_name(dataset_name);
            if isempty(index)
                error(['Data ',dataset_name,' does not exist in activity ',obj.name])
            elseif length(index) > 1
                error(['Multiple datasets links with the same name (',dataset_name,') in activity ',obj.name])
            else
                obj.data = remove_array_index(obj.data, index);
            end
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
        function write_to_disk(obj,hdf5_activities_group_id)
            for i = 1:length(obj)
                activity = obj(i);

                % Create the group with the correct name
                gid = H5G.create(hdf5_activities_group_id,activity.name, 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');
                attr_space_id = H5S.create('H5S_SCALAR');
                str_type_id = H5T.copy('H5T_C_S1');
                H5T.set_size(str_type_id, 'H5T_VARIABLE');
                attr_id = H5A.create(gid, 'activity_name', str_type_id, attr_space_id, 'H5P_DEFAULT');
                H5A.write(attr_id,str_type_id,activity.descriptive_name);
                H5A.close(attr_id);
                H5T.close(str_type_id);
                H5S.close(attr_space_id);

                attr_space_id = H5S.create('H5S_SCALAR');
                str_type_id = H5T.copy('H5T_C_S1');
                H5T.set_size(str_type_id, 'H5T_VARIABLE');
                attr_id = H5A.create(gid, 'activity_date', str_type_id, attr_space_id, 'H5P_DEFAULT');
                H5A.write(attr_id,str_type_id,escdf.datetime_to_iso_utc(activity.activity_date));
                H5A.close(attr_id);
                H5T.close(str_type_id);
                H5S.close(attr_space_id);

                % Create the parameters dataset
                space_id = H5S.create_simple(1,length(activity.metadata_links),length(activity.metadata_links));
                % Create the variable-length string datatype
                str_type_id = H5T.copy('H5T_C_S1');
                H5T.set_size(str_type_id, 'H5T_VARIABLE');
                % Create the dataset with the variable-length string datatype
                dataset_id = H5D.create(gid, 'parameters', str_type_id, space_id, 'H5P_DEFAULT');
                % Write the 1D array of strings to the dataset
                H5D.write(dataset_id, str_type_id, 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', activity.metadata_links);
                % Close the variable-length string datatype
                H5T.close(str_type_id);
                % Close the dataspace
                H5S.close(space_id);
                attr_space_id = H5S.create('H5S_SCALAR');
                str_type_id = H5T.copy('H5T_C_S1');
                H5T.set_size(str_type_id, 'H5T_VARIABLE');
                attr_id = H5A.create(dataset_id, 'data_type', str_type_id, attr_space_id, 'H5P_DEFAULT');
                H5A.write(attr_id,str_type_id,'str');
                H5A.close(attr_id);
                H5T.close(str_type_id);
                H5S.close(attr_space_id);
                % Close the dataset
                H5D.close(dataset_id);

                % Now go through and write each dataset to the group.
                for j = 1:length(activity.data)
                    this_data = activity.data(j);
                    this_gid = H5G.create(gid,this_data.get_name(),'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');
                    this_data.write_to_disk(this_gid);
                    H5G.close(this_gid);
                end
                H5G.close(gid)
            end
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


