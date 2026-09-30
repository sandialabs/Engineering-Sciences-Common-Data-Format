classdef Specification
% SPECIFICATION Canonical local parsed specification file.
%
% A Specification object represents the local parsed contents of a single
% specification file, before inheritance resolution.
%
% Parameters
% ----------
% name : char
%     Specification name.
% version : Version
%     Specification version.
% extends : char
%     Parent specification name, or empty if none.
% documentation : char
%     Freeform documentation block associated with the specification.
% notes : char
%     Freeform notes block associated with the specification.
% local_properties : PropertyDefinition array
%     Canonical local property declarations.
% enumerations : containers.Map
%     Local enumeration definitions.
% Optional name/value arguments:
%   'constraints'
%       ConstraintRule array containing local constraint rules.
%   'storage_hints'
%       StorageHint array containing local storage hints.
%   'source_file'
%       Source file path used to parse the specification.
%
% Notes
% -----
% A Specification contains only directly declared content. It does not
% include inherited parent properties.
%
% See Also
% --------
% PropertyDefinition
% ResolvedSpecification
% SpecificationRegistry

    properties (SetAccess=private)
        name
        version
        extends
        documentation
        notes
        local_properties
        enumerations
        constraints
        storage_hints
        source_file
    end

    methods
        function obj = Specification(name, version, extends, documentation, notes, local_properties, enumerations, varargin)
        % Create a canonical local specification object.
        %
        % Parameters
        % ----------
        % name : char
        %     Specification name.
        % version : Version
        %     Specification version.
        % extends : char
        %     Parent specification name, or empty if none.
        % documentation : char
        %     Freeform documentation block associated with the specification.
        % notes : char
        %     Freeform notes block associated with the specification.
        % local_properties : PropertyDefinition array
        %     Canonical local property declarations.
        % enumerations : containers.Map
        %     Local enumeration definitions.
        % Optional name/value arguments:
        %   'constraints'
        %       ConstraintRule array containing local constraint rules.
        %   'storage_hints'
        %       StorageHint array containing local storage hints.
        %   'source_file'
        %       Source file path used to parse the specification.

            p = inputParser;
            addParameter(p, 'constraints', ConstraintRule.empty(1,0));
            addParameter(p, 'storage_hints', StorageHint.empty(1,0));
            addParameter(p, 'source_file', '', @(x) ischar(x) || isstring(x));
            parse(p, varargin{:});

            if ~(ischar(name) || isstring(name))
                error('Specification name must be a string.');
            end
            if ~isa(version, 'Version')
                error('version must be a Version object.');
            end
            if ~(isempty(extends) || ischar(extends) || isstring(extends))
                error('extends must be a string or empty.');
            end
            if ~ischar(documentation) && ~isstring(documentation)
                error('documentation must be a string.');
            end
            if ~ischar(notes) && ~isstring(notes)
                error('notes must be a string.');
            end
            if ~isempty(local_properties) && ~all(arrayfun(@(x) isa(x,'PropertyDefinition'), local_properties))
                error('local_properties must contain only PropertyDefinition objects.');
            end
            if ~isa(enumerations, 'containers.Map')
                error('enumerations must be a containers.Map.');
            end

            obj.name = char(string(name));
            obj.version = version;
            obj.extends = char(string(extends));
            obj.documentation = char(string(documentation));
            obj.notes = char(string(notes));
            obj.local_properties = local_properties;
            obj.enumerations = enumerations;
            obj.constraints = p.Results.constraints;
            obj.storage_hints = p.Results.storage_hints;
            obj.source_file = char(string(p.Results.source_file));
        end

        function out = property_names(obj)
        % Return sorted unique local property names.
        %
        % Returns
        % -------
        % out : cell array of char
        %     Sorted unique local property names.
            if isempty(obj.local_properties)
                out = {};
                return
            end
            out = unique(arrayfun(@(x) x.name, obj.local_properties, 'UniformOutput', false));
            out = sort(out);
        end
    end
end