classdef SpecificationParser
% SPECIFICATIONPARSER Parser for ESCDF specification text files.
%
% A SpecificationParser converts human-authored ESCDF specification files
% into canonical local Specification objects.
%
% Notes
% -----
% Parsing proceeds conceptually in stages:
%
% 1. raw file parsing
% 2. property normalization
% 3. local Specification construction
%
% Inheritance resolution is intentionally handled by SpecificationRegistry.
%
% See Also
% --------
% Specification
% SpecificationRegistry
% PropertyDefinition
% ConstraintRule
% StorageHint

    methods (Static)
        function spec = parse_file(file_path)
        % Parse a specification file into a canonical local specification.
        %
        % Parameters
        % ----------
        % file_path : char
        %     Path to the specification file.
        %
        % Returns
        % -------
        % spec : Specification
        %     Canonical local specification object.
        %
        % Raises
        % ------
        % error
        %     Raised if the file does not exist or if the specification
        %     contents are malformed.
            if ~(ischar(file_path) || isstring(file_path))
                error('file_path must be a string.');
            end
            file_path = char(string(file_path));

            if ~isfile(file_path)
                error('Specification file not found: %s', file_path);
            end

            txt = fileread(file_path);
            spec = SpecificationParser.parse_text(txt, file_path);
        end

        function spec = parse_text(text, source_file)
        % Parse specification text into a canonical local specification.
        %
        % Parameters
        % ----------
        % text : char
        %     Specification text.
        % source_file : char, optional
        %     Source file path for provenance and debugging.
        %
        % Returns
        % -------
        % spec : Specification
        %     Canonical local specification object.
        %
        % Raises
        % ------
        % error
        %     Raised if the specification text is malformed.
            if nargin < 2
                source_file = '';
            end

            if ~(ischar(text) || isstring(text))
                error('text must be a string.');
            end
            text = char(string(text));

            lines = regexp(text, '\r\n|\n|\r', 'split');
            if isempty(lines)
                error('Specification text is empty.');
            end

            lines = cellfun(@(x) regexprep(x, '\s+$', ''), lines, 'UniformOutput', false);

            [name, version] = SpecificationParser.parse_header_line(lines{1});

            extends_line_index = SpecificationParser.find_extends_line_index(lines);
            extends = SpecificationParser.parse_extends_line(lines);

            properties_section_start = SpecificationParser.find_section_header(lines, 'properties');
            enumerations_section_start = SpecificationParser.find_section_header(lines, 'enumerations');
            constraints_section_start = SpecificationParser.find_section_header(lines, 'constraints');
            chunking_section_start = SpecificationParser.find_section_header(lines, 'chunking');
            storage_hints_section_start = SpecificationParser.find_section_header(lines, 'storage_hints');
            notes_section_start = SpecificationParser.find_section_header(lines, 'notes');

            if isempty(properties_section_start)
                error('Specification "%s" is missing a required "properties" section.', name);
            end

            documentation = SpecificationParser.extract_documentation_block( ...
                lines, extends_line_index, properties_section_start);

            raw_property_lines = SpecificationParser.extract_section_body_lines( ...
                lines, properties_section_start);

            local_properties = PropertyDefinition.empty(1,0);
            constraints = ConstraintRule.empty(1,0);

            for i = 1:length(raw_property_lines)
                [prop, prop_constraints] = SpecificationParser.parse_property_line( ...
                    raw_property_lines{i}, name);
                local_properties(end+1) = prop; %#ok<AGROW>
                if ~isempty(prop_constraints)
                    constraints = [constraints, prop_constraints]; %#ok<AGROW>
                end
            end

            enumerations = containers.Map();
            if ~isempty(enumerations_section_start)
                enumerations = SpecificationParser.parse_enumerations_section( ...
                    lines, enumerations_section_start);
            end

            if ~isempty(constraints_section_start)
                explicit_constraints = SpecificationParser.parse_constraints_section( ...
                    lines, constraints_section_start, name);
                if ~isempty(explicit_constraints)
                    constraints = [constraints, explicit_constraints]; %#ok<AGROW>
                end
            end

            storage_hints = StorageHint.empty(1,0);
            if ~isempty(chunking_section_start)
                chunking_hints = SpecificationParser.parse_chunking_section( ...
                    lines, chunking_section_start, name);
                if ~isempty(chunking_hints)
                    storage_hints = [storage_hints, chunking_hints]; %#ok<AGROW>
                end
            end
            if ~isempty(storage_hints_section_start)
                explicit_hints = SpecificationParser.parse_storage_hints_section( ...
                    lines, storage_hints_section_start, name);
                if ~isempty(explicit_hints)
                    storage_hints = [storage_hints, explicit_hints]; %#ok<AGROW>
                end
            end

            notes = '';
            if ~isempty(notes_section_start)
                notes = SpecificationParser.extract_notes_block(lines, notes_section_start);
            end

            spec = Specification( ...
                name, ...
                version, ...
                extends, ...
                documentation, ...
                notes, ...
                local_properties, ...
                enumerations, ...
                'constraints', constraints, ...
                'storage_hints', storage_hints, ...
                'source_file', source_file);
        end
    end

    methods (Static, Access=private)
        function [name, version] = parse_header_line(header_line)
        % Parse the specification header line.
        %
        % Parameters
        % ----------
        % header_line : char
        %     Header line expected to contain the specification name and
        %     version.
        %
        % Returns
        % -------
        % name : char
        %     Parsed specification name.
        % version : Version
        %     Parsed specification version object.
        %
        % Raises
        % ------
        % error
        %     Raised if the header line is malformed.
            parts = strsplit(header_line, '-');
            if numel(parts) < 2
                error('Invalid specification header line: "%s". Expected format "name - vX.Y.Z".', header_line);
            end

            name_part = strtrim(parts{1});
            version_part = strtrim(strjoin(parts(2:end), '-'));

            if isempty(name_part)
                error('Specification name in header cannot be empty.');
            end

            if ~(startsWith(version_part, 'v'))
                error('Invalid version string "%s". Expected format "vX.Y.Z".', version_part);
            end

            version_numbers = strsplit(strrep(version_part, 'v', ''), '.');
            if numel(version_numbers) ~= 3
                error('Invalid version string "%s". Expected format "vX.Y.Z".', version_part);
            end

            major = str2double(version_numbers{1});
            minor = str2double(version_numbers{2});
            patch = str2double(version_numbers{3});

            if any(isnan([major, minor, patch]))
                error('Invalid version string "%s". Version components must be integers.', version_part);
            end

            name = strrep(strtrim(name_part), ' ', '_');
            version = Version(major, minor, patch);
        end

        function index = find_extends_line_index(lines)
        % Return the index of the extends line.
        %
        % Parameters
        % ----------
        % lines : cell array of char
        %     Specification text lines.
        %
        % Returns
        % -------
        % index : numeric
        %     Index of the extends line.
        %
        % Raises
        % ------
        % error
        %     Raised if no extends line is found.
            index = [];
            for i = 1:length(lines)
                if startsWith(strtrim(lines{i}), 'extends:')
                    index = i;
                    return
                end
            end
            error('Specification is missing an "extends:" line.');
        end

        function parent = parse_extends_line(lines)
        % Parse the parent specification name from the extends line.
        %
        % Parameters
        % ----------
        % lines : cell array of char
        %     Specification text lines.
        %
        % Returns
        % -------
        % parent : char
        %     Parent specification name, or empty if the specification
        %     extends none.
            index = SpecificationParser.find_extends_line_index(lines);
            line = strtrim(lines{index});
            parts = strsplit(line, ':');
            parent = strtrim(parts{2});
            if strcmpi(parent, 'none')
                parent = '';
            end
        end

        function index = find_section_header(lines, section_name)
        % Find the index of a top-level section header.
        %
        % Parameters
        % ----------
        % lines : cell array of char
        %     Specification text lines.
        % section_name : char
        %     Section name to locate.
        %
        % Returns
        % -------
        % index : numeric or empty
        %     Index of the section header, or empty if not found.
            section_name = lower(strtrim(section_name));
            index = [];
            for i = 1:length(lines)
                if strcmpi(strtrim(lines{i}), section_name)
                    index = i;
                    return
                end
            end
        end

        function documentation = extract_documentation_block(lines, extends_line_index, properties_section_start)
        % Extract the documentation block preceding the properties section.
        %
        % Parameters
        % ----------
        % lines : cell array of char
        %     Specification text lines.
        % extends_line_index : numeric
        %     Index of the extends line.
        % properties_section_start : numeric
        %     Index of the properties section header.
        %
        % Returns
        % -------
        % documentation : char
        %     Documentation block text.
            block_lines = lines(extends_line_index+1:properties_section_start-1);
            documentation = SpecificationParser.trim_blank_lines(block_lines);
        end

        function notes = extract_notes_block(lines, notes_section_start)
        % Extract the notes section body.
        %
        % Parameters
        % ----------
        % lines : cell array of char
        %     Specification text lines.
        % notes_section_start : numeric
        %     Index of the notes section header.
        %
        % Returns
        % -------
        % notes : char
        %     Notes block text.
            body_lines = SpecificationParser.extract_section_body_lines(lines, notes_section_start);
            notes = strtrim(strjoin(body_lines, newline));
        end

        function body = extract_section_body_lines(lines, section_start_index)
        % Extract body lines following a top-level section header.
        %
        % Parameters
        % ----------
        % lines : cell array of char
        %     Specification text lines.
        % section_start_index : numeric
        %     Index of the section header line.
        %
        % Returns
        % -------
        % body : cell array of char
        %     Section body lines with leading and trailing blank lines removed.
        %
        % Notes
        % -----
        % This method assumes the current ESCDF section layout in which a
        % section header is followed by an underline line.
            start_index = section_start_index + 2;
            if start_index > length(lines)
                body = {};
                return
            end

            known_section_names = { ...
                'properties', ...
                'enumerations', ...
                'constraints', ...
                'chunking', ...
                'storage_hints', ...
                'notes'};

            body = {};
            i = start_index;
            while i <= length(lines)
                stripped = strtrim(lines{i});
                if any(strcmpi(stripped, known_section_names))
                    break
                end
                body{end+1} = lines{i}; %#ok<AGROW>
                i = i + 1;
            end

            body = SpecificationParser.trim_blank_lines_list(body);
        end

        function text = trim_blank_lines(lines)
        % Trim leading and trailing blank lines and join text.
        %
        % Parameters
        % ----------
        % lines : cell array of char
        %     Input lines.
        %
        % Returns
        % -------
        % text : char
        %     Trimmed joined text.
            trimmed = SpecificationParser.trim_blank_lines_list(lines);
            text = strtrim(strjoin(trimmed, newline));
        end

        function lines_out = trim_blank_lines_list(lines_in)
        % Trim leading and trailing blank lines from a list of lines.
        %
        % Parameters
        % ----------
        % lines_in : cell array of char
        %     Input lines.
        %
        % Returns
        % -------
        % lines_out : cell array of char
        %     Trimmed line list.
            start_index = 1;
            end_index = length(lines_in);

            while start_index <= end_index && isempty(strtrim(lines_in{start_index}))
                start_index = start_index + 1;
            end
            while end_index >= start_index && isempty(strtrim(lines_in{end_index}))
                end_index = end_index - 1;
            end

            if start_index > end_index
                lines_out = {};
            else
                lines_out = lines_in(start_index:end_index);
            end
        end

        function [prop, constraints] = parse_property_line(raw_line, source_specification)
        % Parse one property line into a canonical property definition and
        % any lifted constraint rules.
        %
        % Parameters
        % ----------
        % raw_line : char
        %     Raw property line from the specification.
        % source_specification : char
        %     Name of the specification from which the line originated.
        %
        % Returns
        % -------
        % prop : PropertyDefinition
        %     Parsed canonical property definition.
        % constraints : ConstraintRule array
        %     Lifted relational constraints.
        %
        % Raises
        % ------
        % error
        %     Raised if the property line is malformed.
            line = strtrim(raw_line);
            if isempty(line)
                error('Encountered blank property line unexpectedly.');
            end

            raw_parts = strtrim(strsplit(line, '-'));
            if numel(raw_parts) < 2
                error('Invalid property line: "%s"', raw_line);
            end

            % If regex or other future constructs contain '-', join the tail
            if numel(raw_parts) > 4
                raw_parts = [raw_parts(1:3), {strtrim(strjoin(raw_parts(4:end), '-'))}];
            end

            name = raw_parts{1};
            datatype = raw_parts{2};

            acceptable_datatypes = { ...
                'u1','u2','u4','u8', ...
                'i1','i2','i4','i8', ...
                'f4','f8','c8','c16', ...
                'str','bytes'};
            if ~ismember(datatype, acceptable_datatypes)
                error('Invalid datatype "%s" for property "%s" in specification "%s".', ...
                    datatype, name, source_specification);
            end

            if numel(raw_parts) >= 3 && ~isempty(raw_parts{3})
                shape = SpecificationParser.parse_shape_field(raw_parts{3});
            else
                shape = Dimension.empty(1,0);
            end

            option_tokens = {};
            if numel(raw_parts) >= 4 && ~isempty(raw_parts{4})
                option_tokens = SpecificationParser.split_option_tokens(raw_parts{4});
            end

            optional = false;
            variable_length = false;
            enumeration_name = '';
            regex = '';
            choice_group = '';
            choice_branch = '';
            value_constraints = {};
            constraints = ConstraintRule.empty(1,0);

            for i = 1:length(option_tokens)
                token = option_tokens{i};

                if strcmp(token, 'optional')
                    optional = true;

                elseif strcmp(token, 'variable_length')
                    variable_length = true;

                elseif startsWith(token, 'enum:')
                    enumeration_name = strtrim(extractAfter(token, 'enum:'));

                elseif startsWith(token, 'regex:')
                    regex = strtrim(extractAfter(token, 'regex:'));

                elseif startsWith(token, 'or:')
                    [choice_group, choice_branch] = SpecificationParser.parse_choice_token(token);

                elseif startsWith(token, 'requires:')
                    target = strtrim(extractAfter(token, 'requires:'));
                    constraints(end+1) = ConstraintRule( ...
                        'requires', ...
                        {name}, ...
                        {target}, ...
                        'source_property', name, ...
                        'source_choice_group', choice_group, ...
                        'source_choice_branch', choice_branch, ...
                        'source_specification', source_specification); %#ok<AGROW>

                elseif ismember(token, {'positive','nonnegative','finite', ...
                        'increasing','strictly_increasing','unique','nonempty'})
                    value_constraints{end+1} = token; %#ok<AGROW>

                else
                    error('Unrecognized property option token "%s" on property "%s" in specification "%s".', ...
                        token, name, source_specification);
                end
            end

            prop = PropertyDefinition( ...
                name, ...
                datatype, ...
                shape, ...
                'optional', optional, ...
                'variable_length', variable_length, ...
                'enumeration_name', enumeration_name, ...
                'regex', regex, ...
                'choice_group', choice_group, ...
                'choice_branch', choice_branch, ...
                'value_constraints', value_constraints, ...
                'source_specification', source_specification);
        end

        function dims = parse_shape_field(shape_field)
        % Parse a property shape field.
        %
        % Parameters
        % ----------
        % shape_field : char
        %     Raw shape field text.
        %
        % Returns
        % -------
        % dims : Dimension array
        %     Canonical property shape. Scalars are represented by an empty
        %     array.
        %
        % Raises
        % ------
        % error
        %     Raised if the shape field contains invalid dimension tokens.
            shape_field = strtrim(shape_field);
            if strcmpi(shape_field, 'scalar')
                dims = Dimension.empty(1,0);
                return
            end

            tokens = strsplit(shape_field, ',');
            dims = Dimension.empty(1,0);

            for i = 1:length(tokens)
                token = strtrim(tokens{i});
                if isempty(token)
                    error('Invalid empty dimension token in shape "%s".', shape_field);
                end
                numeric_value = str2double(token);
                if ~isnan(numeric_value)
                    dims(end+1) = Dimension.fixed(numeric_value); %#ok<AGROW>
                else
                    dims(end+1) = Dimension.symbolic(token); %#ok<AGROW>
                end
            end
        end

        function tokens = split_option_tokens(option_field)
        % Split a property option field into option tokens.
        %
        % Parameters
        % ----------
        % option_field : char
        %     Raw options field text.
        %
        % Returns
        % -------
        % tokens : cell array of char
        %     Parsed option tokens.
        %
        % Notes
        % -----
        % Commas inside regex patterns are preserved by treating the first
        % regex: token as consuming the remainder of the field.
            parts = strtrim(strsplit(option_field, ','));
            parts = parts(~cellfun(@isempty, parts));

            if isempty(parts)
                tokens = {};
                return
            end

            regex_index = [];
            for i = 1:length(parts)
                if startsWith(parts{i}, 'regex:')
                    regex_index = i;
                    break
                end
            end

            if ~isempty(regex_index)
                regex_token = strtrim(strjoin(parts(regex_index:end), ','));
                parts = [parts(1:regex_index-1), {regex_token}];
            end

            tokens = parts;
        end

        function [group, branch] = parse_choice_token(token)
        % Parse a choice token in or:group:branch form.
        %
        % Parameters
        % ----------
        % token : char
        %     Raw choice token.
        %
        % Returns
        % -------
        % group : char
        %     Choice-group name.
        % branch : char
        %     Choice-branch name.
        %
        % Raises
        % ------
        % error
        %     Raised if the token is malformed.
            parts = strsplit(token, ':');
            if numel(parts) ~= 3
                error('Invalid choice token "%s". Expected format "or:group:branch".', token);
            end
            group = strtrim(parts{2});
            branch = strtrim(parts{3});

            if isempty(group) || isempty(branch)
                error('Invalid choice token "%s". Group and branch must be nonempty.', token);
            end
        end

        function enumerations = parse_enumerations_section(lines, enumerations_section_start)
        % Parse the enumerations section.
        %
        % Parameters
        % ----------
        % lines : cell array of char
        %     Specification text lines.
        % enumerations_section_start : numeric
        %     Index of the enumerations section header.
        %
        % Returns
        % -------
        % enumerations : containers.Map
        %     Parsed enumeration definitions.
        %
        % Raises
        % ------
        % error
        %     Raised if an enumeration line is malformed.
            body_lines = SpecificationParser.extract_section_body_lines(lines, enumerations_section_start);
            enumerations = containers.Map();

            for i = 1:length(body_lines)
                line = strtrim(body_lines{i});
                if isempty(line)
                    continue
                end

                parts = strtrim(strsplit(line, '-'));
                if numel(parts) < 2
                    error('Invalid enumeration line: "%s"', body_lines{i});
                end

                enum_name = parts{1};
                enum_values_str = strtrim(strjoin(parts(2:end), '-'));
                values = strtrim(strsplit(enum_values_str, ','));
                values = values(~cellfun(@isempty, values));

                if isempty(enum_name)
                    error('Invalid enumeration line: "%s"', body_lines{i});
                end

                enumerations(enum_name) = values;
            end
        end

        function constraints = parse_constraints_section(lines, constraints_section_start, source_specification)
        % Parse an explicit constraints section.
        %
        % Parameters
        % ----------
        % lines : cell array of char
        %     Specification text lines.
        % constraints_section_start : numeric
        %     Index of the constraints section header.
        % source_specification : char
        %     Source specification name.
        %
        % Returns
        % -------
        % constraints : ConstraintRule array
        %     Parsed explicit constraint rules.
        %
        % Notes
        % -----
        % This is currently a placeholder until explicit constraints-section
        % syntax is designed and implemented.
            %#ok<INUSD>
            constraints = ConstraintRule.empty(1,0);
        end

        function storage_hints = parse_chunking_section(lines, chunking_section_start, source_specification)
        % Parse an explicit chunking section.
        %
        % Parameters
        % ----------
        % lines : cell array of char
        %     Specification text lines.
        % chunking_section_start : numeric
        %     Index of the chunking section header.
        % source_specification : char
        %     Source specification name.
        %
        % Returns
        % -------
        % storage_hints : StorageHint array
        %     Parsed chunking-related storage hints.
        %
        % Notes
        % -----
        % This is currently a placeholder until chunking-section syntax is
        % designed and implemented.
            %#ok<INUSD>
            storage_hints = StorageHint.empty(1,0);
        end

        function storage_hints = parse_storage_hints_section(lines, storage_hints_section_start, source_specification)
        % Parse an explicit storage-hints section.
        %
        % Parameters
        % ----------
        % lines : cell array of char
        %     Specification text lines.
        % storage_hints_section_start : numeric
        %     Index of the storage_hints section header.
        % source_specification : char
        %     Source specification name.
        %
        % Returns
        % -------
        % storage_hints : StorageHint array
        %     Parsed storage hints.
        %
        % Notes
        % -----
        % This is currently a placeholder until explicit storage-hints
        % syntax is designed and implemented.
            %#ok<INUSD>
            storage_hints = StorageHint.empty(1,0);
        end
    end
end