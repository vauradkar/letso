// use poem_openapi::ApiResponse;
// use poem_openapi::payload::Json;
// use poem_openapi::payload::PlainText;
// use shlib::Directory;

// #[derive(ApiResponse)]
// pub(crate) enum ApiErrors {
//     #[oai(status = 200)]
//     Todo(Json<Directory>),
//
//     #[oai(status = 500)]
//     ReadError(PlainText<String>),
//
//     #[oai(status = 400)]
//     InvalidArgument(PlainText<String>),
// }
//
// impl From<shlib::Error> for ApiErrors {
//     fn from(err: shlib::Error) -> Self {
//         match err {
//             shlib::Error::ReadError { what, how } => {
//                 ApiErrors::ReadError(PlainText(format!("Failed to read
// {what}: {how}")))             }
//             shlib::Error::InvalidArgument(msg) =>
// ApiErrors::InvalidArgument(PlainText(msg)),
// shlib::Error::ParseError { what, how } => {
// ApiErrors::ReadError(PlainText(format!("Failed to parse {what}: {how}")))
//             }
//         }
//     }
// }
