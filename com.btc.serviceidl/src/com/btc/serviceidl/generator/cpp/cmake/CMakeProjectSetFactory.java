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
package com.btc.serviceidl.generator.cpp.cmake;

import org.eclipse.core.runtime.IPath;
import org.eclipse.xtext.generator.IFileSystemAccess;

import com.btc.serviceidl.generator.ITargetVersionProvider;
import com.btc.serviceidl.generator.common.PackageInfo;
import com.btc.serviceidl.generator.common.ParameterBundle;
import com.btc.serviceidl.generator.common.ProjectType;
import com.btc.serviceidl.generator.cpp.ExternalDependency;
import com.btc.serviceidl.generator.cpp.IModuleStructureStrategy;
import com.btc.serviceidl.generator.cpp.IProjectReference;
import com.btc.serviceidl.generator.cpp.IProjectSet;
import com.btc.serviceidl.generator.cpp.IProjectSetFactory;
import com.btc.serviceidl.generator.cpp.ProjectFileSet;

public class CMakeProjectSetFactory implements IProjectSetFactory {

    @Override
    public IProjectSet create() {
        return new CMakeProjectSet();
    }

    @Override
    public void generateProjectFiles(IFileSystemAccess fileSystemAccess,
            IModuleStructureStrategy moduleStructureStrategy, ITargetVersionProvider targetVersionProvider,
            ParameterBundle parameterBundle, Iterable<ExternalDependency> externalDependencies,
            Iterable<PackageInfo> importedDependencies, IProjectSet projectSet,
            Iterable<IProjectReference> projectReferences, ProjectFileSet projectFileSet, ProjectType projectType,
            IPath projectPath, String projectName) {
        new CMakeProjectFileGenerator(fileSystemAccess, moduleStructureStrategy, targetVersionProvider,
                externalDependencies, projectReferences, importedDependencies, projectFileSet, projectType, projectPath,
                projectName).generate();
    }

}
