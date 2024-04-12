IMPORT os
DEFINE m_xcf       om.DomDocument
DEFINE m_resources DICTIONARY OF STRING
DEFINE m_env       DICTIONARY OF STRING
MAIN
	DEFINE l_file STRING
	DEFINE l_path STRING
	DEFINE l_mod  STRING
	DEFINE l_n    om.DomNode
	DEFINE l_envs DYNAMIC ARRAY OF STRING
	DEFINE x      SMALLINT

-- some defaults
	LET m_resources["res.path.isv"]        = fgl_getenv("ISVHOME")
	LET m_resources["res.path.separator"]  = "/"
	LET m_resources["res.deployment.root"] = os.Path.join(fgl_getenv("FGLASDIR"), "appdata/deployment")
	LET m_env["FGL_WEBSERVER_REMOTE_ADDR"] = "127.0.0.1"

	LET l_file = base.Application.getArgument(1)
	CALL readXcf(l_file)

	LET l_file = base.Application.getArgument(2)
	CALL readXcf(l_file)

	LET l_envs = m_env.getKeys()
	FOR x = 1 TO l_envs.getLength()
		IF l_envs[x] != "PATH" THEN
			DISPLAY SFMT("set %1=%2", l_envs[x], m_env[l_envs[x]])
			CALL fgl_setenv(l_envs[x], m_env[l_envs[x]])
		END IF
	END FOR

	LET l_n    = m_xcf.getDocumentElement().selectByTagName("PATH").item(1)
	LET l_path = resolveRes2(l_n.getFirstChild().getAttribute("@chars"))
	LET l_n    = m_xcf.getDocumentElement().selectByTagName("MODULE").item(1)
	LET l_mod  = resolveRes2(l_n.getFirstChild().getAttribute("@chars"))
	DISPLAY SFMT("Path: %1 Module: %2", l_path, l_mod)

	IF os.Path.chDir(l_path) THEN
		DISPLAY SFMT("cd %1", l_path)
		DISPLAY SFMT("fglrun %1", l_mod)
		RUN SFMT("fglrun %1", l_mod)
	ELSE
		DISPLAY SFMT("cd %1 failed!", l_path)
	END IF
END MAIN
--------------------------------------------------------------------------------
FUNCTION readXcf(l_file STRING)

	IF NOT os.Path.exists(l_file) THEN
		DISPLAY SFMT("XCF file '%1' not found.", l_file)
		EXIT PROGRAM 1
	END IF

	TRY
		LET m_xcf = om.DomDocument.createFromXmlFile(l_file)
	CATCH
		DISPLAY SFMT("XCF file '%1' failed to open %2: %3.", l_file, status, err_get(status))
		EXIT PROGRAM 1
	END TRY

	CALL getResources(m_xcf.getDocumentElement())
	CALL getEnv(m_xcf.getDocumentElement())

END FUNCTION
--------------------------------------------------------------------------------
FUNCTION getEnv(l_root om.DomNode)
	DEFINE l_nl  om.NodeList
	DEFINE l_n   om.DomNode
	DEFINE x     SMALLINT
	DEFINE l_val STRING
	LET l_nl = l_root.selectByTagName("ENVIRONMENT_VARIABLE")
	FOR x = 1 TO l_nl.getLength()
		LET l_n   = l_nl.item(x)
		LET l_val = l_n.getFirstChild().getAttribute("@chars")
		LET l_val = resolveRes2(l_val)
		DISPLAY SFMT("Env: %1 = %2", l_n.getAttribute("Id"), l_val)
		LET m_env[l_n.getAttribute("Id")] = l_val
	END FOR
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION getResources(l_root om.DomNode)
	DEFINE l_nl      om.NodeList
	DEFINE l_n, l_n2 om.DomNode
	DEFINE x         SMALLINT
	LET l_nl = l_root.selectByTagName("RESOURCE")
	FOR x = 1 TO l_nl.getLength()
		LET l_n  = l_nl.item(x)
		LET l_n2 = l_n.getFirstChild()
		IF l_n2 IS NOT NULL THEN
			DISPLAY SFMT("Resource: %1 = %2", l_n.getAttribute("Id"), l_n2.getAttribute("@chars"))
			LET m_resources[l_n.getAttribute("Id")] = l_n2.getAttribute("@chars")
		END IF
	END FOR
	CALL resolveResources(1)
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION resolveResources(l_depth SMALLINT)
	DEFINE l_keys DYNAMIC ARRAY OF STRING
	DEFINE l_val  STRING
	DEFINE x, y   SMALLINT
	DEFINE l_more BOOLEAN = FALSE
	LET l_keys = m_resources.getKeys()
	FOR x = 1 TO l_keys.getLength()
		LET l_val = m_resources[l_keys[x]]
		LET y     = l_val.getIndexOf("$(", 1)
		LET l_val = resolveRes2(l_val)
		IF l_val != m_resources[l_keys[x]] THEN
			LET m_resources[l_keys[x]] = l_val
			LET l_more                 = TRUE
			DISPLAY SFMT("%1:Resource2: %2 = %3", l_depth, l_keys[x], l_val)
		ELSE
			DISPLAY SFMT("%1:Resource1: %2 = %3", l_depth, l_keys[x], l_val)
		END IF
	END FOR
	IF l_more AND l_depth < 3 THEN
		CALL resolveResources(l_depth + 1)
	END IF
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION resolveRes2(l_str STRING)
	DEFINE y, z, l SMALLINT
	DEFINE l_key   STRING
	LET y = l_str.getIndexOf("$(", 1)
	LET l = l_str.getLength()
	IF y > 0 THEN
		LET z     = l_str.getIndexOf(")", y)
		LET l_key = l_str.subString(y + 2, z - 1)
		IF m_resources.contains(l_key) THEN
			DISPLAY SFMT("Resource '%1' found, val: %2", l_key, m_resources[l_key])
			LET l_str = l_str.subString(1, y - 1), m_resources[l_key], l_str.subString(z + 1, l)
		ELSE
			DISPLAY SFMT("Resource '%1' not found!", l_key)
		END IF
	END IF
	RETURN l_str
END FUNCTION
