document.onreadystatechange = function () {
  if (document.readyState === 'complete') {
    var ci = document.getElementById('company_name');
    ci.value = data.company_name;
    
    ci = document.getElementById('side_spacing');
    ci.value = data.side_spacing;

    if (data.dir_labels == true){
      ci = document.getElementById('dir_labelsY');
      ci.checked = true;
    } else {
      ci = document.getElementById('dir_labelsN');
      ci.checked = true;
    }

    if (data.roundup == true){
      ci = document.getElementById('roundupY');
      ci.checked = true;
    } else {
      ci = document.getElementById('roundupN');
      ci.checked = true;
    }

    if (data.list_by_tag == true){
      ci = document.getElementById('list_by_tagY');
      ci.checked = true;
    } else {
      ci = document.getElementById('list_by_tagN');
      ci.checked = true;
    }
    
    if (data.metric == true){
      ci = document.getElementById('metric');
      ci.checked = true;
    } else {
      ci = document.getElementById('english');
      ci.checked = true;
    }
    
    if (data.list_file_format == "C"){
      ci = document.getElementById('lff_csv');
      ci.checked = true;
    } else if (data.list_file_format == "T") {
      ci = document.getElementById('lff_txt');
      ci.checked = true;
    } else {
      ci = document.getElementById('lff_xls');
      ci.checked = true;
    }

    if (data.roll == true){
      ci = document.getElementById('roll');
      ci.checked = true;
    } else {
      ci = document.getElementById('unwrap');
      ci.checked = true;
    }      

    ci = document.getElementById('min_extra_timber_length');
    ci.value = data.min_extra_timber_length;

    if (data.qty == true){
      ci = document.getElementById('qtyY');
      ci.checked = true;
      show_qty_config();
    } else {
      ci = document.getElementById('qtyN');
      ci.checked = true;
      hide_qty_config();
    }

    ci = document.getElementById('sq_x');
    ci.value = data.sq_x_pos;

    ci = document.getElementById('sq_y');
    ci.value = data.sq_y_pos;

    ci = document.getElementById('sq_font_size');
    ci.value = data.sq_font_size;

    ci = document.getElementById('sq_rotate');
    ci.value = data.sq_rotate;

    if (data.sq_bold == true){
      ci = document.getElementById('sq_boldY');
      ci.checked = true;
    } else {
      ci = document.getElementById('sq_boldN');
      ci.checked = true;
    }    
    
    ci = document.getElementById('vp2dx');
    ci.value = data.vp2dx;
    
    ci = document.getElementById('vp2dy');
    ci.value = data.vp2dy;
    
    ci = document.getElementById('vp2dw');
    ci.value = data.vp2dw;
    
    ci = document.getElementById('vp2dh');
    ci.value = data.vp2dh;
        
    ci = document.getElementById('vp3dx');
    ci.value = data.vp3dx;

    ci = document.getElementById('vp3dy');
    ci.value = data.vp3dy;

    ci = document.getElementById('vp3dw');
    ci.value = data.vp3dw;

    ci = document.getElementById('vp3dh');
    ci.value = data.vp3dh;

    if (data.t3do == "H"){
      ci = document.getElementById('t3d_horizontal');
      ci.checked = true;
    } else if (data.t3do == "V") {
      ci = document.getElementById('t3d_vertical');
      ci.checked = true;
    } else {
      ci = document.getElementById('t3d_none');
      ci.checked = true;
    }
  }
}

function show_qty_config(){
  console.log("show");
  document.getElementById('size_qty_div').style.visibility = 'visible';
}

function hide_qty_config(){
  console.log("hide");
  document.getElementById('size_qty_div').style.visibility = 'hidden';
}

function save_data() {
  var ci = document.getElementById('company_name');
  data.company_name = ci.value;

  ci = document.getElementById('side_spacing');
  data.side_spacing = ci.value;

  ci = document.getElementById('dir_labelsY');
  data.dir_labels = ci.checked;

  ci = document.getElementById('roundupY');
  data.roundup = ci.checked;

  ci = document.getElementById('list_by_tagY');
  data.list_by_tag = ci.checked;            
  
  ci = document.getElementById('metric');
  data.metric = ci.checked;            
  
  ci = document.getElementById('lff_csv');
  if (ci.checked){
    data.list_file_format = "C";
  };
  ci = document.getElementById('lff_txt');
  if (ci.checked){
    data.list_file_format = "T";
  };
  ci = document.getElementById('lff_xls');
  if (ci.checked){
    data.list_file_format = "X";
  };

  ci = document.getElementById('roll');
  data.roll = ci.checked;            

  ci = document.getElementById('min_extra_timber_length');
  data.min_extra_timber_length = ci.value;

  ci = document.getElementById('qtyY');
  data.qty = ci.checked;

  ci = document.getElementById('sq_x');
  data.sq_x_pos = ci.value;

  ci = document.getElementById('sq_y');
  data.sq_y_pos = ci.value;

  ci = document.getElementById('sq_font_size');
  data.sq_font_size = ci.value;

  ci = document.getElementById('sq_rotate');
  data.sq_rotate = ci.value;

  ci = document.getElementById('sq_boldY');
  data.sq_bold = ci.checked;  

  ci = document.getElementById('vp2dx');
  data.vp2dx = ci.value;

  ci = document.getElementById('vp2dy');
  data.vp2dy = ci.value;

  ci = document.getElementById('vp2dw');
  data.vp2dw = ci.value;

  ci = document.getElementById('vp2dh');
  data.vp2dh = ci.value;

  ci = document.getElementById('vp3dx');
  data.vp3dx = ci.value;

  ci = document.getElementById('vp3dy');
  data.vp3dy = ci.value;

  ci = document.getElementById('vp3dw');
  data.vp3dw = ci.value;

  ci = document.getElementById('vp3dh');
  data.vp3dh = ci.value;

  ci = document.getElementById('t3d_vertical');
  if (ci.checked){
    data.t3do = "V";
  };
  ci = document.getElementById('t3d_horizontal');
  if (ci.checked){
    data.t3do = "H";
  };
  ci = document.getElementById('t3d_none');
  if (ci.checked){
    data.t3do = "N";
  };

  sketchup.tf_save_config(data);
}
