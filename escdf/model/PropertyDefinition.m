classdef PropertyDefinition
% PROPERTYDEFINITION Canonical normalized property declaration.
%
% A PropertyDefinition represents one normalized property declaration from
% a specification file.
%
% Parameters
% ----------
% name : char
%     Property name.
% datatype : char
%     ESCDF datatype code.
% shape : Dimension array
%     Ordered property shape definition. Scalars are represented by an
%     empty array.
% Optional name/value arguments:
%   'optional'
%       Logical scalar indicating unconditional schema optionality.
%   'variable_length'
%       Logical scalar indicating variable-length / ragged storage.
%   'enumeration_name'
%       Enumeration name constraining the property values.
%   'regex'
%       Regular expression constraining the property values.
%   'choice_group'
%       Choice-group name for this declaration.
%   'choice_branch'
%       Branch name within the choice group.
%   'value_constraints'
%       Cell array of intrinsic value-constraint names.
%   'source_specification'
%       Name of the specification from which the declaration originated.
%
% Notes
% -----
% This object represents exactly one canonical property declaration.
% Relational modifiers such as requires:* must not remain attached after
% normalization; they are lifted into ConstraintRule objects.
%
% See Also
% --------
% Dimension
% ConstraintRule
% Specification

    properties (SetAccess=private)
        name
        datatype
        shape
        optional
        variable_length
        enumeration_name
        regex
        choice_group
        choice_branch
        value_constraints
        source_specification
    end

    methods
        function obj = PropertyDefinition(name, datatype, shape, varargin)
        % Create a canonical property definition.
        %
        % Parameters
        % ----------
        % name : char
        %     Property name.
        % datatype : char
        %     ESCDF datatype code.
        % shape : Dimension array
        %     Ordered property shape definition.
        % Optional name/value arguments:
        %   'optional'
        %       Logical scalar indicating unconditional schema optionality.
        %   'variable_length'
        %       Logical scalar indicating variable-length / ragged storage.
        %   'enumeration_name'
        %       Enumeration name constraining the property values.
        %   'regex'
        %       Regular expression constraining the property values.
        %   'choice_group'
        %       Choice-group name for this declaration.
        %   'choice_branch'
        %       Branch name within the choice group.
        %   'value_constraints'
        %       Cell array of intrinsic value-constraint names.
        %   'source_specification'
        %       Name of the specification from which the declaration originated.
        %
        % Raises
        % ------
        % error
        %     Raised if the supplied fields are malformed or internally
        %     inconsistent.

            p = inputParser;
            addRequired(p, 'name', @(x) ischar(x) || isstring(x));
            addRequired(p, 'datatype', @(x) ischar(x) || isstring(x));
            addRequired(p, 'shape');
            addParameter(p, 'optional', false, @(x) islogical(x) && isscalar(x));
            addParameter(p, 'variable_length', false, @(x) islogical(x) && isscalar(x));
            addParameter(p, 'enumeration_name', '', @(x) ischar(x) || isstring(x));
            addParameter(p, 'regex', '', @(x) ischar(x) || isstring(x));
            addParameter(p, 'choice_group', '', @(x) ischar(x) || isstring(x));
            addParameter(p, 'choice_branch', '', @(x) ischar(x) || isstring(x));
            addParameter(p, 'value_constraints', {}, @(x) iscell(x));
            addParameter(p, 'source_specification', '', @(x) ischar(x) || isstring(x));
            parse(p, name, datatype, shape, varargin{:});

            obj.name = char(string(p.Results.name));
            obj.datatype = char(string(p.Results.datatype));

            if isempty(obj.name)
                error('PropertyDefinition name must be nonempty.');
            end

            acceptable_datatypes = { ...
                'u1','u2','u4','u8', ...
                'i1','i2','i4','i8', ...
                'f4','f8','c8','c16', ...
                'str','bytes'};

            if ~ismember(obj.datatype, acceptable_datatypes)
                error('PropertyDefinition datatype "%s" is not valid.', obj.datatype);
            end

            if isempty(shape)
                obj.shape = Dimension.empty(1,0);
            else
                if ~all(arrayfun(@(x) isa(x,'Dimension'), shape))
                    error('PropertyDefinition shape must contain only Dimension objects.');
                end
                obj.shape = shape;
            end

            obj.optional = p.Results.optional;
            obj.variable_length = p.Results.variable_length;
            obj.enumeration_name = char(string(p.Results.enumeration_name));
            obj.regex = char(string(p.Results.regex));
            obj.choice_group = char(string(p.Results.choice_group));
            obj.choice_branch = char(string(p.Results.choice_branch));
            obj.value_constraints = p.Results.value_constraints;
            obj.source_specification = char(string(p.Results.source_specification));

            has_choice_group = ~isempty(strtrim(obj.choice_group));
            has_choice_branch = ~isempty(strtrim(obj.choice_branch));
            if xor(has_choice_group, has_choice_branch)
                error('choice_group and choice_branch must either both be set or both be empty.');
            end
        end

        function out = is_scalar(obj)
        % Return whether this property is scalar.
        %
        % Returns
        % -------
        % out : logical
        %     True if the property is scalar.
            out = isempty(obj.shape);
        end

        function out = is_choice_member(obj)
        % Return whether this property belongs to a choice group.
        %
        % Returns
        % -------
        % out : logical
        %     True if the property belongs to a choice group.
            out = ~isempty(strtrim(obj.choice_group));
        end

        function out = shape_repr(obj)
        % Return a compact character representation of the property shape.
        %
        % Returns
        % -------
        % out : char
        %     Shape representation. Scalars are returned as 'scalar'.
            if obj.is_scalar()
                out = 'scalar';
            else
                out = strjoin(arrayfun(@char, obj.shape, 'UniformOutput', false), ',');
            end
        end

        function disp(obj)
        % Display the property definition.
            fprintf('PropertyDefinition: %s (%s, %s)\n', ...
                obj.name, obj.datatype, obj.shape_repr());
        end
    end
end