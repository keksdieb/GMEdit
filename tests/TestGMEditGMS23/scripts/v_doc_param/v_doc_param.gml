/// @param {int} a,b
function v_doc_param_1() {
	
}
/// @param {int} [a,b]
function v_doc_param_2() {
	
}
/// @param {int} a,b = 1
function v_doc_param_3() {
	
}

function v_doc_param() {
	// argument types should show up for each of these with "Show argument types in status bar" checked
	v_doc_param_1(1, 2);
	v_doc_param_2(1, 2);
	v_doc_param_3(1, 2);
}