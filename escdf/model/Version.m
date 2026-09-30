classdef Version
% VERSION Version number for an ESCDF specification.
%
% A Version object stores the three-part semantic version associated with
% one specification definition.
%
% Parameters
% ----------
% major : numeric
%     Major version number.
% minor : numeric
%     Minor version number.
% patch : numeric
%     Patch version number.
%
% Notes
% -----
% A version is associated with a specification itself, not with inherited
% ancestry as a composite object.
%
% See Also
% --------
% Specification
% ResolvedSpecification

    properties (SetAccess=private)
        major
        minor
        patch
    end

    methods
        function obj = Version(major, minor, patch)
        % Create a specification version object.
        %
        % Parameters
        % ----------
        % major : numeric
        %     Major version number.
        % minor : numeric
        %     Minor version number.
        % patch : numeric
        %     Patch version number.
        %
        % Raises
        % ------
        % error
        %     Raised if any version component is not a nonnegative integer.
            arguments
                major (1,1) double
                minor (1,1) double
                patch (1,1) double
            end

            if any([major, minor, patch] < 0) || ...
               any(mod([major, minor, patch], 1) ~= 0)
                error('Version components must be nonnegative integers.');
            end

            obj.major = major;
            obj.minor = minor;
            obj.patch = patch;
        end

        function out = as_array(obj)
        % Return the version as a numeric row vector.
        %
        % Returns
        % -------
        % out : 1x3 double
        %     Version in the form [major minor patch].
            out = [obj.major, obj.minor, obj.patch];
        end

        function out = char(obj)
        % Return a character representation of the version.
        %
        % Returns
        % -------
        % out : char
        %     Version string in the form vX.Y.Z.
            out = sprintf('v%d.%d.%d', obj.major, obj.minor, obj.patch);
        end

        function disp(obj)
        % Display the version.
            fprintf('%s\n', char(obj));
        end
    end
end