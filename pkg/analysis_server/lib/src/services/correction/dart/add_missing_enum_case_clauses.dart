// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/src/services/correction/dart/abstract_producer.dart';
import 'package:analysis_server/src/services/correction/fix.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

class AddMissingEnumCaseClauses extends CorrectionProducer {
  @override
  // Adding the missing case is not a sufficient fix (user logic needs adding
  // too).
  bool get canBeAppliedInBulk => false;

  @override
  // Adding the missing case is not a sufficient fix (user logic needs adding
  // too).
  bool get canBeAppliedToFile => false;

  @override
  FixKind get fixKind => DartFixKind.ADD_MISSING_ENUM_CASE_CLAUSES;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    if (node is! SwitchStatement) {
      return;
    }
    var statement = node as SwitchStatement;

    String? enumName;
    var enumConstantNames = <String>[];
    var expressionType = statement.expression.staticType;
    if (expressionType is InterfaceType) {
      var enumElement = expressionType.element2;
      if (enumElement is EnumElement) {
        enumName = enumElement.name;
        for (var field in enumElement.fields) {
          if (field.isEnumConstant) {
            enumConstantNames.add(field.name);
          }
        }
      }
    }
    if (enumName == null) {
      return;
    }
    for (var member in statement.members) {
      if (member is SwitchCase) {
        var expression = member.expression;
        if (expression is Identifier) {
          var element = expression.staticElement;
          if (element is PropertyAccessorElement) {
            enumConstantNames.remove(element.name);
          }
        }
      }
    }
    if (enumConstantNames.isEmpty) {
      return;
    }

    var statementIndent = utils.getLinePrefix(statement.offset);
    var singleIndent = utils.getIndent(1);
    var location = utils.newCaseClauseAtEndLocation(statement);

    final enumName_final = enumName;
    await builder.addDartFileEdit(file, (builder) {
      // TODO(brianwilkerson) Consider inserting the names in order into the
      //  switch statement.
      builder.addInsertion(location.offset, (builder) {
        builder.write(location.prefix);
        for (var constantName in enumConstantNames) {
          builder.write(statementIndent);
          builder.write(singleIndent);
          builder.write('case ');
          builder.write(enumName_final);
          builder.write('.');
          builder.write(constantName);
          builder.writeln(':');
          builder.write(statementIndent);
          builder.write(singleIndent);
          builder.write(singleIndent);
          builder.writeln('// TODO: Handle this case.');
          builder.write(statementIndent);
          builder.write(singleIndent);
          builder.write(singleIndent);
          builder.writeln('break;');
        }
        builder.write(location.suffix);
      });
    });
  }
}
