classdef HDF5Location
% HDF5LOCATION Runtime-local HDF5 backing location.
%
% An HDF5Location identifies an HDF5 object by normalized file path and
% internal HDF5 object path.
%
% Parameters
% ----------
% file_path : char
%     HDF5 file path.
% object_path : char
%     Internal HDF5 object path.
% file_uuid : char, optional
%     Optional future persistent file identifier.
%
% Notes
% -----
% This object is intended as a runtime/session-local descriptor. It is not
% currently intended to be a persistent cross-machine identifier.

    properties (SetAccess=private)
        file_path
        object_path
        file_uuid
    end

    methods
        function obj = HDF5Location(file_path, object_path, file_uuid)
        % Create an HDF5 backing location.
        %
        % Parameters
        % ----------
        % file_path : char
        %     HDF5 file path.
        % object_path : char
        %     Internal HDF5 object path.
        % file_uuid : char, optional
        %     Optional future persistent file identifier.
            if nargin < 3
                file_uuid = '';
            end

            obj.file_path = HDF5Location.normalize_file_path(file_path);
            obj.object_path = HDF5Location.normalize_object_path(object_path);
            obj.file_uuid = char(string(file_uuid));
        end

        function tf = same_file_as(obj, other)
        % Return whether two locations refer to the same file.
        %
        % Parameters
        % ----------
        % other : HDF5Location
        %     Other location.
        %
        % Returns
        % -------
        % tf : logical
        %     True if both locations refer to the same file.
            if ~isa(other, 'HDF5Location')
                tf = false;
                return
            end

            if ~isempty(obj.file_uuid) && ~isempty(other.file_uuid)
                tf = strcmp(obj.file_uuid, other.file_uuid);
            else
                tf = strcmp(obj.file_path, other.file_path);
            end
        end

        function tf = same_location_as(obj, other)
        % Return whether two locations refer to the same HDF5 object.
        %
        % Parameters
        % ----------
        % other : HDF5Location
        %     Other location.
        %
        % Returns
        % -------
        % tf : logical
        %     True if both locations refer to the same file and object path.
            tf = isa(other, 'HDF5Location') && ...
                 obj.same_file_as(other) && ...
                 strcmp(obj.object_path, other.object_path);
        end
    end

    methods (Static)
        function out = normalize_file_path(file_path)
        % Normalize an HDF5 file path.
        %
        % Parameters
        % ----------
        % file_path : char
        %     Input file path.
        %
        % Returns
        % -------
        % out : char
        %     Canonical file path.
            out = char(java.io.File(char(string(file_path))).getCanonicalPath());
        end

        function out = normalize_object_path(object_path)
        % Normalize an HDF5 internal object path.
        %
        % Parameters
        % ----------
        % object_path : char
        %     Input HDF5 object path.
        %
        % Returns
        % -------
        % out : char
        %     Normalized HDF5 object path.
            out = char(string(object_path));
            if isempty(out)
                out = '/';
            end
            if ~startsWith(out, '/')
                out = ['/', out];
            end
            if length(out) > 1 && endsWith(out, '/')
                out = out(1:end-1);
            end
        end

        function location = from_hdf5_id(h5_id)
        % Construct a location from an HDF5 object identifier.
        %
        % Parameters
        % ----------
        % h5_id : numeric
        %     HDF5 object identifier.
        %
        % Returns
        % -------
        % location : HDF5Location
        %     Backing location for the HDF5 object.
            file_id = H5I.get_file_id(h5_id);
            file_name = H5F.get_name(file_id);
            H5F.close(file_id);

            object_path = H5I.get_name(h5_id);
            location = HDF5Location(file_name, object_path);
        end

        function location = child_of_group(h5g_id, child_name)
        % Construct the location of a child object under an HDF5 group.
        %
        % Parameters
        % ----------
        % h5g_id : numeric
        %     Parent HDF5 group identifier.
        % child_name : char
        %     Child object name.
        %
        % Returns
        % -------
        % location : HDF5Location
        %     Expected child HDF5 location.
            file_id = H5I.get_file_id(h5g_id);
            file_name = H5F.get_name(file_id);
            H5F.close(file_id);

            group_path = H5I.get_name(h5g_id);

            if strcmp(group_path, '/')
                object_path = ['/', char(string(child_name))];
            else
                object_path = [group_path, '/', char(string(child_name))];
            end

            location = HDF5Location(file_name, object_path);
        end
    end
end