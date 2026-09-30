classdef StorageHint
% STORAGEHINT Canonical advisory storage hint for a property.
%
% A StorageHint represents a storage-related default recommendation for a
% property, such as chunking or access-pattern strategy.
%
% Parameters
% ----------
% property_name : char
%     Property to which the hint applies.
% kind : char
%     Storage-hint kind, such as chunking or strategy.
% value : any
%     Associated hint value.
% Optional name/value arguments:
%   'overridable'
%       Logical scalar indicating whether user code may override the hint.
%   'source_specification'
%       Specification from which the hint originated.
%
% Notes
% -----
% Storage hints are advisory defaults, not schema-validity requirements.
%
% See Also
% --------
% Specification
% ResolvedSpecification

    properties (SetAccess=private)
        property_name
        kind
        value
        overridable
        source_specification
    end

    methods
        function obj = StorageHint(property_name, kind, value, varargin)
        % Create an advisory storage hint.
        %
        % Parameters
        % ----------
        % property_name : char
        %     Property to which the hint applies.
        % kind : char
        %     Storage-hint kind.
        % value : any
        %     Associated storage-hint value.
        % Optional name/value arguments:
        %   'overridable'
        %       Logical scalar indicating whether user code may override the hint.
        %   'source_specification'
        %       Specification from which the hint originated.
        %
        % Raises
        % ------
        % error
        %     Raised if required fields are malformed.

            p = inputParser;
            addRequired(p, 'property_name', @(x) ischar(x) || isstring(x));
            addRequired(p, 'kind', @(x) ischar(x) || isstring(x));
            addRequired(p, 'value');
            addParameter(p, 'overridable', true, @(x) islogical(x) && isscalar(x));
            addParameter(p, 'source_specification', '', @(x) ischar(x) || isstring(x));
            parse(p, property_name, kind, value, varargin{:});

            obj.property_name = char(string(p.Results.property_name));
            obj.kind = char(string(p.Results.kind));
            obj.value = p.Results.value;
            obj.overridable = p.Results.overridable;
            obj.source_specification = char(string(p.Results.source_specification));

            if isempty(strtrim(obj.property_name))
                error('property_name must be nonempty.');
            end
            if isempty(strtrim(obj.kind))
                error('kind must be nonempty.');
            end
        end
    end
end