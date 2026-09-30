classdef ResolvedSpecification
% RESOLVEDSPECIFICATION Fully resolved effective specification.
%
% A ResolvedSpecification represents the effective specification after
% inheritance resolution and eagerly constructed derived indexes.
%
% Parameters
% ----------
% name : char
%     Resolved specification name.
% version : Version
%     Version of the resolved specification.
% ancestry : cell array of char
%     Ordered ancestry chain in inheritance application order, beginning
%     with the root ancestor and ending with the resolved specification.
% property_definitions : PropertyDefinition array
%     Effective property declarations after inheritance resolution.
% enumerations : containers.Map
%     Effective enumeration definitions after inheritance resolution.
% constraints : ConstraintRule array
%     Effective constraint rules after inheritance resolution.
% storage_hints : StorageHint array
%     Effective storage hints after inheritance resolution.
%
% Notes
% -----
% A ResolvedSpecification eagerly computes derived indexes used for
% validation, debugging, and documentation generation.
%
% See Also
% --------
% Specification
% SpecificationRegistry

    properties (SetAccess=private)
        name
        version
        ancestry
        property_definitions
        enumerations
        constraints
        storage_hints

        properties_by_name
        choice_groups
        standalone_properties
        required_properties
        optional_properties
        property_names
        dimension_names
    end

    methods
        function obj = ResolvedSpecification(name, version, ancestry, property_definitions, enumerations, constraints, storage_hints)
        % Create a fully resolved effective specification.
        %
        % Parameters
        % ----------
        % name : char
        %     Resolved specification name.
        % version : Version
        %     Version of the resolved specification.
        % ancestry : cell array of char
        %     Ordered ancestry chain in inheritance application order.
        % property_definitions : PropertyDefinition array
        %     Effective property declarations after inheritance resolution.
        % enumerations : containers.Map
        %     Effective enumeration definitions after inheritance resolution.
        % constraints : ConstraintRule array
        %     Effective constraint rules after inheritance resolution.
        % storage_hints : StorageHint array
        %     Effective storage hints after inheritance resolution.

            if ~(ischar(name) || isstring(name))
                error('ResolvedSpecification name must be a string.');
            end
            if ~isa(version, 'Version')
                error('version must be a Version object.');
            end
            if ~iscellstr(ancestry)
                error('ancestry must be a cell array of strings.');
            end
            if ~isempty(property_definitions) && ~all(arrayfun(@(x) isa(x,'PropertyDefinition'), property_definitions))
                error('property_definitions must contain only PropertyDefinition objects.');
            end
            if ~isa(enumerations, 'containers.Map')
                error('enumerations must be a containers.Map.');
            end
            if ~isempty(constraints) && ~all(arrayfun(@(x) isa(x,'ConstraintRule'), constraints))
                error('constraints must contain only ConstraintRule objects.');
            end
            if ~isempty(storage_hints) && ~all(arrayfun(@(x) isa(x,'StorageHint'), storage_hints))
                error('storage_hints must contain only StorageHint objects.');
            end

            obj.name = char(string(name));
            obj.version = version;
            obj.ancestry = ancestry(:).';
            obj.property_definitions = property_definitions;
            obj.enumerations = enumerations;
            obj.constraints = constraints;
            obj.storage_hints = storage_hints;

            obj.properties_by_name = obj.build_properties_by_name();
            obj.choice_groups = obj.build_choice_groups();
            obj.standalone_properties = property_definitions(~arrayfun(@(p) p.is_choice_member(), property_definitions));
            obj.required_properties = obj.standalone_properties(~[obj.standalone_properties.optional]);
            obj.optional_properties = obj.standalone_properties([obj.standalone_properties.optional]);
            obj.property_names = sort(keys(obj.properties_by_name));
            obj.dimension_names = obj.build_dimension_names();
        end
    end

    methods (Access=private)
        function out = build_properties_by_name(obj)
            out = containers.Map();
            for i = 1:length(obj.property_definitions)
                prop = obj.property_definitions(i);
                if ~isKey(out, prop.name)
                    out(prop.name) = PropertyDefinition.empty(1,0);
                end
                current = out(prop.name);
                current(end+1) = prop;
                out(prop.name) = current;
            end
        end

        function out = build_choice_groups(obj)
            out = containers.Map();
            for i = 1:length(obj.property_definitions)
                prop = obj.property_definitions(i);
                if ~prop.is_choice_member()
                    continue
                end
                if ~isKey(out, prop.choice_group)
                    out(prop.choice_group) = containers.Map();
                end
                branch_map = out(prop.choice_group);
                if ~isKey(branch_map, prop.choice_branch)
                    branch_map(prop.choice_branch) = PropertyDefinition.empty(1,0);
                end
                branch_props = branch_map(prop.choice_branch);
                branch_props(end+1) = prop;
                branch_map(prop.choice_branch) = branch_props;
                out(prop.choice_group) = branch_map;
            end
        end

        function out = build_dimension_names(obj)
            names = {};
            for i = 1:length(obj.property_definitions)
                prop = obj.property_definitions(i);
                for j = 1:length(prop.shape)
                    dim = prop.shape(j);
                    if dim.is_symbolic()
                        names{end+1} = dim.value; %#ok<AGROW>
                    end
                end
            end
            out = sort(unique(names));
        end
    end
end