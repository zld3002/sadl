/************************************************************************
 * Copyright © 2007-2016 - General Electric Company, All Rights Reserved
 *
 * Project: SADL
 *
 * Description: The Semantic Application Design Language (SADL) is a
 * language for building semantic models and expressing rules that
 * capture additional domain knowledge. The SADL-IDE (integrated
 * development environment) is a set of Eclipse plug-ins that
 * support the editing and testing of semantic models using the
 * SADL language.
 *
 * This software is distributed "AS-IS" without ANY WARRANTIES
 * and licensed under the Eclipse Public License - v 1.0
 * which is available at http://www.eclipse.org/org/documents/epl-v10.php
 *
 ***********************************************************************/
package com.ge.research.sadl.tests

import com.ge.research.sadl.sADL.SadlModel
import com.google.common.base.Charsets
import com.google.inject.Inject
import java.io.File
import java.nio.file.Files
import java.nio.file.StandardOpenOption
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.XtextRunner
import org.eclipse.xtext.testing.util.ParseHelper
import org.eclipse.xtext.testing.validation.ValidationTestHelper
import org.eclipse.xtext.resource.FileExtensionProvider
import org.eclipse.xtext.validation.Issue
import org.junit.Ignore
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(XtextRunner)
@InjectWith(SADLInjectorProvider)
class GenerateTestCases {
	
	@Inject ParseHelper<SadlModel> parseHelper
	@Inject ValidationTestHelper validationHelper
	@Inject FileExtensionProvider extensionProvider 
	
	@Ignore @Test def void generateTestCasesFromExamples() {
		val root = new File("../../../..")
		println(root.canonicalFile.absolutePath)
		testParseRecursive(root)
	}
	
	def void testParseRecursive(File file) {
		if (file.isDirectory) {
			for (f : file.listFiles) {
				testParseRecursive(f)
			}
		} else {
			if (file.name.endsWith("."+extensionProvider.primaryFileExtension)) {
				try {
					val contents = Files.readAllLines(file.toPath, Charsets.ISO_8859_1).join('\n')+"\n"
					val model = parseHelper.parse(contents)
					val issues = validationHelper.validate(model)
					generateTest(file, model, issues, contents)				
					if (!issues.isEmpty) {
						println("Errors in "+file.name)
					} else {
						println("No errors in "+file.name)
					}
				} catch (Exception e) {
					println("Failed reading "+file.name+" - " +e.message)
				}
			}
		}
	}
	
	def generateTest(File file, SadlModel model, Iterable<Issue> issues, String contents) {
		val typename = (file.parentFile.name.toFirstUpper+"_"+file.name.substring(0, file.name.length-6).toFirstUpper+"Test").replace('-','_')
		val packagePath = 'com/ge/research/sadl/tests/generated'
		val toBeGenerated = new File('./src/'+packagePath+'/'+typename+".xtend")
		if (!toBeGenerated.parentFile.exists) {
			toBeGenerated.parentFile.mkdir
		}
//		var processedContents = contents
//		for (issue : issues.sortBy[-offset]) {
//			processedContents = processedContents.substring(0, issue.offset)+'/* ERROR : ' + issue.message + '*/' + processedContents.substring(issue.offset)
//		}
		Files.write(toBeGenerated.toPath, '''
			package «packagePath.replace('/','.')»
			
			import org.junit.Test
			import com.ge.research.sadl.tests.SADLParsingTest
			
			class «typename» extends SADLParsingTest {
				
				@Test def void testParse() {
					'«»''
						«contents»
					'«»''.assertNoErrors
					«FOR issue : issues»
						// «issue.lineNumber» : «issue.message»
					«ENDFOR»
				}
			}
		'''.toString.bytes, StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING)
	}
	
}