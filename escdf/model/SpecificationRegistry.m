classdef SpecificationRegistry < handle
% SPECIFICATIONREGISTRY Registry for loading and resolving ESCDF specifications.
%
% A SpecificationRegistry is responsible for:
%
% - loading specification files from disk
% - parsing them into local Specification objects
% - resolving inheritance into ResolvedSpecification objects
% - caching both local and resolved forms
%
% See Also
% --------
% Specification
% ResolvedSpecification
% SpecificationParser

    properties (Access=private)
        local_specifications
        resolved_specifications
        loaded_directories
    end

    methods
        function obj = SpecificationRegistry()
        % Create an empty specification registry.
            obj.local_specifications = containers.Map();
            obj.resolved_specifications = containers.Map();
            obj.loaded_directories = {};
        end

        function clear(obj)
        % Clear all registry state.
            obj.local_specifications = containers.Map();
            obj.resolved_specifications = containers.Map();
            obj.loaded_directories = {};
        end

        function tf = has_local(obj, name)
        % Return whether a local specification is loaded.
            tf = isKey(obj.local_specifications, name);
        end

        function tf = has_resolved(obj, name)
        % Return whether a resolved specification is cached.
            tf = isKey(obj.resolved_specifications, name);
        end

        function spec = get_local(obj, name)
        % Return a loaded local specification.
            if ~isKey(obj.local_specifications, name)
                error('No local specification named "%s" is loaded.', name);
            end
            spec = obj.local_specifications(name);
        end

        function spec = get_resolved(obj, name)
        % Return a cached resolved specification.
            if ~isKey(obj.resolved_specifications, name)
                error('No resolved specification named "%s" is loaded.', name);
            end
            spec = obj.resolved_specifications(name);
        end

        function names = list_local_names(obj)
        % Return loaded local specification names.
            names = sort(keys(obj.local_specifications));
        end

        function names = list_resolved_names(obj)
        % Return cached resolved specification names.
            names = sort(keys(obj.resolved_specifications));
        end

        function load_from_directory(obj, directory)
        % Load specification files from a directory.
        %
        % Parameters
        % ----------
        % directory : char
        %     Directory containing specification text files.
        %
        % Raises
        % ------
        % error
        %     Raised if the directory does not exist or duplicate specification
        %     names are encountered.
            if ~(ischar(directory) || isstring(directory))
                error('directory must be a string.');
            end
            directory = char(string(directory));
            if ~isfolder(directory)
                error('Specification directory not found: %s', directory);
            end

            files = dir(fullfile(directory, '*.txt'));
            for i = 1:length(files)
                spec_path = fullfile(files(i).folder, files(i).name);
                spec = SpecificationParser.parse_file(spec_path);
                obj.add_local_specification(spec);
            end

            obj.resolved_specifications = containers.Map();
            if ~any(strcmp(obj.loaded_directories, directory))
                obj.loaded_directories{end+1} = directory;
            end
        end

        function add_local_specification(obj, specification)
        % Add a local specification to the registry.
            if ~isa(specification, 'Specification')
                error('specification must be a Specification object.');
            end
            if isKey(obj.local_specifications, specification.name)
                error('A local specification named "%s" already exists.', specification.name);
            end
            obj.local_specifications(specification.name) = specification;
        end

        function add_resolved_specification(obj, specification)
        % Add or replace a resolved specification in the cache.
            if ~isa(specification, 'ResolvedSpecification')
                error('specification must be a ResolvedSpecification object.');
            end
            obj.resolved_specifications(specification.name) = specification;
        end

        function spec = resolve(obj, specification_name)
        % Resolve and return an effective specification.
        %
        % Parameters
        % ----------
        % specification_name : char
        %     Name of the specification to resolve.
        %
        % Returns
        % -------
        % spec : ResolvedSpecification
        %     Effective resolved specification object.

            specification_name = char(string(specification_name));
            if isKey(obj.resolved_specifications, specification_name)
                spec = obj.resolved_specifications(specification_name);
                return
            end

            local_spec = obj.get_local(specification_name);
            chain = obj.build_resolution_chain(specification_name);

            ancestry = cellfun(@(s) s.name, fliplr(chain), 'UniformOutput', false);

            property_definitions = PropertyDefinition.empty(1,0);
            enumerations = containers.Map();
            constraints = ConstraintRule.empty(1,0);
            storage_hints = StorageHint.empty(1,0);

            for i = length(chain):-1:1
                spec_i = chain{i};

                if ~isempty(spec_i.local_properties)
                    property_definitions = [property_definitions, spec_i.local_properties]; %#ok<AGROW>
                end

                enum_keys = keys(spec_i.enumerations);
                for j = 1:length(enum_keys)
                    enumerations(enum_keys{j}) = spec_i.enumerations(enum_keys{j});
                end

                if ~isempty(spec_i.constraints)
                    constraints = [constraints, spec_i.constraints]; %#ok<AGROW>
                end

                storage_hints = obj.merge_storage_hints(storage_hints, spec_i.storage_hints);
            end

            spec = ResolvedSpecification( ...
                local_spec.name, ...
                local_spec.version, ...
                ancestry, ...
                property_definitions, ...
                enumerations, ...
                constraints, ...
                storage_hints);

            obj.resolved_specifications(specification_name) = spec;
        end

        function resolve_all(obj)
        % Resolve all loaded local specifications.
            names = obj.list_local_names();
            for i = 1:length(names)
                obj.resolve(names{i});
            end
        end

        function reload(obj)
        % Reload all previously loaded specification directories.
            directories = obj.loaded_directories;
            obj.clear();
            for i = 1:length(directories)
                obj.load_from_directory(directories{i});
            end
        end
    end

    methods (Access=private)
        function chain = build_resolution_chain(obj, specification_name)
            chain = {};
            seen = {};
            current_name = specification_name;

            while ~isempty(current_name)
                if any(strcmp(seen, current_name))
                    error('Inheritance cycle detected while resolving "%s".', specification_name);
                end
                seen{end+1} = current_name; %#ok<AGROW>

                spec = obj.get_local(current_name);
                chain{end+1} = spec; %#ok<AGROW>

                if isempty(spec.extends)
                    current_name = '';
                else
                    current_name = spec.extends;
                end
            end
        end

        function merged = merge_storage_hints(obj, existing_hints, new_hints) %#ok<INUSD>
            merged = existing_hints;
            for i = 1:length(new_hints)
                new_hint = new_hints(i);
                found = false;
                for j = 1:length(merged)
                    old_hint = merged(j);
                    if strcmp(old_hint.property_name, new_hint.property_name) && ...
                       strcmp(old_hint.kind, new_hint.kind)
                        merged(j) = new_hint;
                        found = true;
                        break
                    end
                end
                if ~found
                    merged(end+1) = new_hint; %#ok<AGROW>
                end
            end
        end
    end

    methods (Static)
        function spec_dir = get_default_specification_directory()
        % Return the packaged ESCDF specification directory.
        %
        % Returns
        % -------
        % spec_dir : char
        %     Path to the packaged ESCDF specification directory.
            this_file = mfilename('fullpath');
            this_dir = fileparts(this_file);
            spec_dir = fullfile(fileparts(this_dir), 'specifications');
        end

        function registry = build_default_registry()
        % Build a specification registry from the packaged ESCDF specifications.
        %
        % Returns
        % -------
        % registry : SpecificationRegistry
        %     Registry loaded from the packaged specification directory.
            registry = SpecificationRegistry();
            registry.load_from_directory(SpecificationRegistry.get_default_specification_directory());
        end
    end
end