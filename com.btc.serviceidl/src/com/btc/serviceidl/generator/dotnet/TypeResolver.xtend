/*********************************************************************
 * \author see AUTHORS file
 * \copyright 2015-2018 BTC Business Technology Consulting AG and others
 * 
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 * 
 * SPDX-License-Identifier: EPL-2.0
 **********************************************************************/
package com.btc.serviceidl.generator.dotnet

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.Names
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.ResolvedName
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.AliasDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.util.Constants
import java.util.HashSet
import java.util.Set
import java.util.regex.Pattern
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.naming.QualifiedName

import static extension com.btc.serviceidl.generator.common.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors(PACKAGE_GETTER)
class TypeResolver
{
    public static val PROTOBUF_UUID_TYPE = "Google.ProtocolBuffers.ByteString"

    val DotNetFrameworkVersion frameworkVersion
    val IQualifiedNameProvider qualifiedNameProvider
    val Set<String> namespaceReferences
    val Set<FailableAlias> failableAliases
    val Set<String> referencedAssemblies = new HashSet<String>
    val Set<ParameterBundle> projectReferences = new HashSet<ParameterBundle>
    val NuGetPackageResolver nugetPackageResolver
    val VSSolution vsSolution
    val ParameterBundle parameterBundle

    def ResolvedName resolve(String name)
    {
        val effective_name = resolveException(name) ?: name
        val fully_qualified_name = QualifiedName.create(
            effective_name.split(Pattern.quote(Constants.SEPARATOR_PACKAGE)))
        val namespace = fully_qualified_name.skipLast(1).toString

        if (namespace.startsWith("System"))
            referencedAssemblies.add(DotNetAssemblies.getAssemblyForNamespace(namespace, frameworkVersion))
        else
        {
            val assemblyName = AssemblyResolver.resolveReference(namespace)
            nugetPackageResolver.resolvePackage(assemblyName)
        }

        namespaceReferences.add(namespace)
        return new ResolvedName(fully_qualified_name, TransformType.PACKAGE, false)
    }

    def ResolvedName resolve(EObject element)
    {
        return resolve(element, element.mainProjectType)
    }

    def ResolvedName resolve(EObject element, ProjectType project_type)
    {
        val fully_qualified = true

        // use the underlying type for typedefs
        if (element instanceof AliasDeclaration)
        {
            return resolve(element.ultimateType)
        }

        val name = qualifiedNameProvider.getFullyQualifiedName(element)
        if (name === null)
        {
            if (element instanceof AbstractType)
            {
                if (element.primitiveType !== null)
                {
                    return resolve(element.primitiveType, project_type)
                }
                else if (element.referenceType !== null)
                {
                    return resolve(element.referenceType, if (project_type != ProjectType.PROTOBUF)
                        element.referenceType.mainProjectType
                    else
                        project_type)
                }
            }
            else if (element instanceof PrimitiveType)
            {
                if (element.uuidType !== null)
                {
                    if (project_type == ProjectType.PROTOBUF)
                        return resolve(PROTOBUF_UUID_TYPE)
                    else
                        return resolve("System.Guid")
                }
                else
                    return new ResolvedName(primitiveTypeName(element), TransformType.PACKAGE, fully_qualified)
            }
            return new ResolvedName(Names.plain(element), TransformType.PACKAGE, fully_qualified)
        }

        var result = GeneratorUtil.getFullyQualifiedClassName(element, name, project_type, ArtifactNature.DOTNET,
            TransformType.PACKAGE)

        val package_name = QualifiedName.create(result.split(Pattern.quote(Constants.SEPARATOR_PACKAGE))).skipLast(1)
        if (!isSameProject(package_name))
        {
            // just use namespace, no assembly required - project reference will be used instead!
            namespaceReferences.add(package_name.toString)
            element.resolveProjectFilePath(project_type)
        }

        return new ResolvedName(result, TransformType.PACKAGE, fully_qualified)
    }

    private static def String resolveException(String name)
    {
        // temporarily some special handling for exceptions, because not all
        // C++ CAB exceptions are supported by the .NET CAB
        switch (name)
        {
            case "BTC.Commons.Core.InvalidArgumentException":
                return "System.ArgumentException"
            default:
                return null
        }
    }

    private def boolean isSameProject(QualifiedName referenced_package)
    {
        GeneratorUtil.getTransformedModuleName(parameterBundle, ArtifactNature.DOTNET, TransformType.PACKAGE) ==
            referenced_package.toString
    }

    def void resolveProjectFilePath(EObject referenced_object, ProjectType project_type)
    {
        projectReferences.add(
            new ParameterBundle.Builder().with(referenced_object.moduleStack).with(project_type).build)
    }

    def primitiveTypeName(PrimitiveType element)
    {
        if (element.integerType !== null)
        {
            switch element.integerType
            {
                case "int64":
                    return "long"
                case "int32":
                    return "int"
                case "int16":
                    return "short"
                case "byte":
                    return "byte"
            }
        }
        else if (element.stringType !== null)
            return "string"
        else if (element.floatingPointType !== null)
        {
            switch element.floatingPointType
            {
                case "double":
                    return "double"
                case "float":
                    return "float"
            }
        }
        else if (element.uuidType !== null)
        {
            return resolve("System.Guid").fullyQualifiedName
        }
        else if (element.booleanType !== null)
            return "bool"
        else if (element.charType !== null)
            return "char"

        throw new IllegalArgumentException("Unknown PrimitiveType: " + element.class.toString)
    }

    def String resolveFailableProtobufType(EObject element, EObject container)
    {
        val namespace = GeneratorUtil.getTransformedModuleName(
            ParameterBundle.createBuilder(container.scopeDeterminant.moduleStack).with(ProjectType.PROTOBUF).build,
            ArtifactNature.DOTNET,
            TransformType.PACKAGE
        )
        return namespace + TransformType.PACKAGE.separator +
            GeneratorUtil.asFailable(element, container, qualifiedNameProvider)
    }

    def String resolveFailableType(String basicType)
    {
        resolve(FailableAlias.CONTAINER_TYPE)
        val failableAlias = new FailableAlias(basicType)
        failableAliases.add(failableAlias)
        return failableAlias.aliasName
    }
}
